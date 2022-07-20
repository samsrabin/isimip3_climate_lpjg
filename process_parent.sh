#!/bin/bash
set -e
###############################################################
# SUMMARY
#
# Submits a series of jobs that convert the original GGCMI phase 3 climate forcing netCDFs into versions that LPJ-GUESS can work with. Each job is a call to process_child.sh; see that script for more details. Jobs are submitted via Slurm and will run in sequence (one after the other).
#
#
###############################################################

# If testing: how many files?
ntest=3

#########################################################################
# Function-parsing code from https://gist.github.com/neatshell/5283811

script="process_parent.sh"

#Declare the number of mandatory args
margs=1

# Common functions - BEGIN
function example {
echo -e "example: $script -g GFDL-ESM4 -p \"picontrol historical\" -x"
}

function usage {
echo -e "usage: $script -g GCM_OR_REANALYSIS [-p "PERIOD1 PERIOD2" -x]\n"
}

clim_list="counterclim obsclim spinclim transclim"
period_list_3a="historical"
period_list_3b="picontrol historical ssp126 ssp370 ssp585"
products_3a=("GSWP3-W5E5" "20CRv3" "20CRv3-ERA5" "20CRv3-W5E5")
products_3b=("GFDL-ESM4" "IPSL-CM6A-LR" "MPI-ESM1-2-HR" "MRI-ESM2-0" "UKESM1-0-LL")


function help {
usage
echo -e "MANDATORY:"
echo -e "  GCM_OR_REANALYSIS  The GCM(s) (3b) or reanalysis product(s) (3a) to upload. One of (3a) ${products_3a[@]} (3b) ${products_3a[@]}."
echo -e "OPTIONAL for phase 3a (ignored for 3b):"
echo -e "  -c, --clim       VAL   The \"clim\" we'll be processing (default all: ${clim_list})"
echo -e "OPTIONAL:"
echo -e "  -d, --dependency JOBNUM  Job number on which the first submitted processing job will depend."
echo -e "  -p, --periods VAL        Space-separated list of periods to process. Default is all periods for the phase associated with the given GCM or reanalysis product (3a: ${period_list_3a}; 3b: ${period_list_3b})."
echo -e "  -P, --partition VAL      Partition to use."
echo -e "  -s, --subperiods VAL     Space-separated list of subperiods to process. Only applies for picontrol period. Default is all: \"picontrol historical ssp126\"."
echo -e "  -t, --testing            Add this flag to only process precip (and only ${ntest} files of that)."
echo -e "  -v, --variables VAL      Space-separated list of climate variables to process. Default is all: \"hurs pr rsds sfcwind tas tasmax tasmin\""
echo -e "  -x, --execute            Add this flag to actually submit the processing, instead of just listing what will be processed."
echo -e "  -h,  --help              Prints this help\n"
example
}

# Ensures that the number of passed args are at least equals
# to the declared number of mandatory args.
# It also handles the special case of the -h or --help arg.
function margs_precheck {
if [ $2 ] && [ $1 -lt $margs ]; then
    if [ $2 == "--help" ] || [ $2 == "-h" ]; then
        help
        exit
    else
        usage
        example
        exit 1 # error
    fi
fi
}

# Ensures that all the mandatory args are not empty
function margs_check {
if [ $# -lt $margs ]; then
    usage
    example
    exit 1 # error
fi
}
# Common functions - END

# Main
margs_precheck $# $1

# Get GCM (or reanalysis product)
gcm=$1
if [[ "${gcm}" == "" ]]; then
    echo "You must provide a GCM or reanalysis product"
    exit 1
elif [[ "${gcm}" == "-h" || "${gcm}" == "--help" ]]; then
    help
    exit
fi
gcm_lower=$(echo ${gcm} | tr '[:upper:]' '[:lower:]') # Ensure lowercase
shift
containsElement () {
    local e match="$1"
    shift
    for e; do 
        if [[ "$e" == "$match" ]]; then
            echo 1
            return 0
        fi
    done
    echo 0
    return 0
}

# Set (default values of) phase-dependent variables
if [[ "$(containsElement "${gcm}" "${products_3a[@]}")" -eq 1 ]]; then
    phase="3a"
    period_list="${period_list_3a}"
elif [[ "$(containsElement "${gcm}" "${products_3b[@]}")" -eq 1 ]]; then
    phase="3b"
    period_list="${period_list_3b}"
    clim_list=""
else
    echo "Phase not known for GCM/reanalysis product ${gcm}"
    exit 1
fi
dir_phase="climate${phase}"

# Set other default values
testing=0
partition="iojobs"
justlist=1
dependency=""
depend_after="afterany"
varlist="hurs pr rsds sfcwind tas tasmax tasmin"
subperiod_list="picontrol historical ssp126"

# Args while-loop
while [ "$1" != "" ];
do
    case $1 in
        -c  | --clim)  shift
            clim_list="$1"
            ;;
        -x  | --execute  )  justlist=0
            ;;
        -t  | --testing  )  testing=1
            ;;
        -p  | --periods )  shift
            period_list=$1
            ;;
        -s  | --subperiods)  shift
            subperiod_list="$1"
            ;;
        -P  | --partition)  shift
            partition=$1
            ;;
        -d  | --dependency )  shift
            if [[ "$1" == "after"* ]]; then
                depend_after=$(echo $1 | grep -oE "^after[a-z]+")
                depend_job=$(echo $1 | grep -oE "[0-9]+")
            else
                depend_after="afterany"
                depend_job="$1"
            fi
            dependency="-d ${depend_after}:${depend_job}"
            ;;
        -v  | --variables)  shift
            varlist=$1
            ;;
        -h   | --help )        help
            exit
            ;;
        *)
            echo "$script: illegal option $1"
            usage
            example
            exit 1 # error
            ;;
    esac
    shift
done

# Pass here your mandatory args for check
margs_check $gcm

# End function-parsing code
#########################################################################

if [[ ${phase} == "3b" && "${clim_list}" != "" ]]; then
    echo "-c/--clim ${clim} is ignored for phase 3b"
    clim_list=""
fi

# Which child script to use?
childscript=process_child.sh

# Set up testing vs. not
if [[ "${testing}" != 0 ]]; then
	childmem="8G"
	varlist="pr"
else
	childmem="62G"
fi

# Deflation level
deflate_lvl=1

# Check period list
if [[ "${dependency}" == "" ]]; then
    for clim in ${clim_list}; do
    for period in ${period_list}; do
    	if [[ ! -d "${dir_phase}/${period}" ]]; then
    		echo "${dir_phase}/${period}/ does not exist."
    		exit 1
    	elif [[ ${phase} == "3a" && ! -d "${dir_phase}/${period}/${clim}/${gcm}" ]]; then
    		echo "${dir_phase}/${period}/${clim}/${gcm}/ does not exist."
    		exit 1
    	elif [[ ${phase} == "3b" && ! -d "${dir_phase}/${period}/${gcm}" ]]; then
    		echo "${dir_phase}/${period}/${gcm}/ does not exist."
    		exit 1
    	fi
    done
    done # clim
else
    echo "Skipping check for existence of ${dir_phase}/${period} because dependency is specified."
fi

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

# Submit jobs, looping through periods and variables (and clim_list, if 3a)
for clim in ${clim_list}; do
for period in ${period_list}; do

    dir_period="${dir_phase}/${period}"
    if [[ ${phase} == "3a" ]]; then
 	    gcmdir_orig="${dir_period}/${clim}/${gcm}"
    elif [[ ${phase} == "3b" ]]; then
 	    gcmdir_orig="${dir_period}/${gcm}"
    fi

	# What are all the years in this period?
	# (will be overwritten using $period_actual, called from submit_child.sh,
    # if $period=="picontrol")
	. ./get_years.sh

	# Set up directories
	. ./get_dirnames.sh
	mkdir -p ${gcmdir_logs}
	mkdir -p ${gcmdir_tmp}
	mkdir -p ${gcmdir_lpjg}

	# Submit if needed, looping through sub-periods of picontrol if needed
	for var in ${varlist}; do
		if [[ "${period}" == "picontrol" ]]; then
			for period_actual in ${subperiod_list}; do
				. ./submit_child.sh
			done
		else
			period_actual=""
			. ./submit_child.sh
		fi
	done
	echo " "


done
done # clim

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
	echo "Nothing submitted; add -x to submit."
fi

exit 0
