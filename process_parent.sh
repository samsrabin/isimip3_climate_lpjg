#!/bin/bash
set -e
###############################################################
# SUMMARY
#
# Submits a series of jobs that convert the original GGCMI phase 3 climate forcing netCDFs into versions that LPJ-GUESS can work with. Each job is a call to process_child.sh; see that script for more details. Jobs are submitted via Slurm and will run in sequence (one after the other).
#
#
# USAGE
#
# process_parent.sh $phase $period $gcm
#
#    phase:  3a or 3b
#    period: Quoted, space-separated list of time periods to process.
#            E.g.: "picontrol historical ssp126 ssp370 ssp585"
#    gcm:    GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, or UKESM1-0-LL
#            (not case-sensitive)
###############################################################

# Just list files that will be processed?
justlist=0

# If testing is anything other than zero: Only process pr
testing=0
ntest=3

# Which partition to use?
#partition="interlagos"
#partition="sandy"
#partition="fat"
partition="iojobs"
#partition="ivy"
#partition="ivyshort"

# Which child script to use?
childscript=process_child.sh

# How much memory should each child process use?
if [[ "${testing}" == 0 ]]; then
	childmem="62G"
else
	childmem="8G"
fi

# Deflation level
deflate_lvl=1

# Get list of variables to process
if [[ "${testing}" == 0 ]]; then
	varlist="pr hurs rsds sfcwind tas tasmax tasmin"
else
	varlist="pr"
fi

# Arguments: Phase, period, and GCM
. ./get_arguments.sh
period_list=$2
if [[ "${period_list}" == "" ]]; then
	echo "You must provide an argument (2nd) for period_list."
	exit 1
else
	for period in ${period_list}; do
		if [[ ! -d "${dir_phase}/${period}" ]]; then
			echo "${dir_phase}/${period}/ does not exist."
			exit 1
		elif [[ ! -d "${dir_phase}/${period}/${gcm}" ]]; then
			echo "${dir_phase}/${period}/${gcm}/ does not exist."
			exit 1
		fi
	done
fi

# Set up
dependency=""
#dependency="-d afterany:164280"

# Sanity checks
if [[ ! -e ${childscript} ]]; then
	echo "childscript ${childscript} does not exist"
	exit 1
fi

# Print information
echo "partition: ${partition}"
echo "child script: ${childscript}"
echo "child memory: ${childmem}"
date
echo " "

# Submit jobs, looping through periods and variables
for period in ${period_list}; do

	dir_period="${dir_phase}/${period}"
	gcmdir_orig="${dir_period}/${gcm}"

	# What are all the years in this period?
	# (will be overwritten using $period_actual if $period=="picontrol")
	. ./get_years.sh

	# Set up directories
	. ./get_dirnames.sh
	mkdir -p ${gcmdir_logs}
	mkdir -p ${gcmdir_tmp}
	mkdir -p ${gcmdir_lpjg}

	# Submit if needed, looping through sub-periods of picontrol if needed
	for var in ${varlist}; do
		if [[ "${period}" == "picontrol" ]]; then
			# Only need one of the future periods
			for period_actual in picontrol historical ssp126; do
				. ./submit_child.sh
			done
		else
			period_actual=""
			. ./submit_child.sh
		fi
	done
	echo " "


done

# Submit jobs, looping through commands that were saved for later
for ((i=0;i<${#command_list[@]};++i)); do
	thecommand="${command_list[i]}"
	partition_submit="${partition_submit_list[i]}"
	childmem_submit="${childmem_submit_list[i]}"
	thisid="${thisid_list[i]}"
	. ./submit_grandchild.sh
done
echo " "

if [[ ${justlist} == 0 ]]; then
	echo "All submitted!"
	date
else
	echo "Nothing submitted because \$justlist != 0"
fi

exit 0
