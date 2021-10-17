#!/bin/bash
set -e

# Uploads climate files from Midway cluster, with an "automated kicking machine" to ensure that the transfer is restarted when the connection goes bad for some reason.

#############################################################################################
# Function-parsing code from https://gist.github.com/neatshell/5283811

script="check_processed_existence.sh"
#Declare the number of mandatory args
margs=0

# Common functions - BEGIN
function example {
echo -e "example: $script -g GFDL-ESM4 -p \"picontrol historical\""
}

function usage {
echo -e "usage: $script [-g "GCM1 GCM2 REANALYSIS1" -p "3APERIOD1 3BPERIOD1 3BPERIOD2"]\n"
}

function help {
usage
echo -e "OPTIONAL:"
echo -e "  -g, --gcms  VAL  The list of reanalysis products and/or GCMs to check. Default \"GSWP3 GSWP3-W5E5 GFDL-ESM4 IPSL-CM6A-LR MPI-ESM1-2-HR MRI-ESM2-0 UKESM1-0-LL\"\n"
echo -e "  -p, --periods VAL  Space-separated list of periods to upload. Default is all periods for the phase associated with included GCMs and/or reanalysis products (\"spinclim obsclim counterclim picontrol historical ssp126 ssp370 ssp585\")"
echo -e "  -v, --variables VAL  Space-separated list of climate variables to upload. Default is all: \"hurs pr rsds sfcwind tas tasmax tasmin\""
echo -e "  -n, --no_check_timesteps  Flag to disable checking of file timesteps (i.e., only check existence)."
echo -e "  -h,  --help             Prints this help\n"
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

# Set default values
gcms="GSWP3 GSWP3-W5E5 GFDL-ESM4 IPSL-CM6A-LR MPI-ESM1-2-HR MRI-ESM2-0 UKESM1-0-LL"
period_list="spinclim obsclim counterclim picontrol historical ssp126 ssp370 ssp585"
var_list="hurs pr rsds sfcwind tas tasmax tasmin"
check_timesteps=1

# Args while-loop
while [ "$1" != "" ];
do
	case $1 in
		-g  | --gcms )  shift
			gcms=$1
			;;
		-p  | --periods )  shift
			period_list=$1
			;;
		-v  | --variables)  shift
			var_list=$1
			;;
		-n  | --no_check_timesteps  )  check_timesteps=0
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

## Pass here your mandatory args for check
#margs_check $gcms

# End function-parsing code
#############################################################################################

function do_check {

gcm_lower=$1
period=$2
period_actual=$3
if [[ "${period_actual}" == "xyz" ]]; then
	period_actual=""
fi
var=$4
check_timesteps=$5
phase=$6

if [[ "${phase}" == "" ]]; then
	echo "Error in call of do_check"
	exit 1
fi

# Get years in this period
. ./get_years.sh

# Check for existing output file(s)
gcmdir_lpjg="climate${phase}/${period}/${gcm}-lpjg"
file_nc4="${gcmdir_lpjg}/${gcm_lower}_*_${period}_${var}_global_daily_${firstyear}_${lastyear}.nc4"
result=$(ls ${file_nc4} 2>/dev/null | wc -l)

if [[ "${result}" == 0 ]]; then
	echo "    Missing: ${file_nc4}"
elif [[ "${result}" != 1 ]]; then
	echo " "
	echo "ERROR: Bad result of check for missing file. Message:"
	echo ${result}
	exit 1
	#	else
	#		echo "OK: ${file_nc4}"
fi

# Check existence
if [[ ${check_timesteps} == 1 && "${result}" == 1 ]]; then
	f=${file_nc4}
	. ./do_check_timesteps.sh
	if [[ ${badts} == 1 ]]; then
		result=2
	fi
fi

}

# Set up output file
checksdir=logs_checks
mkdir -p logs_checks
datecode=$(date +"%Y%m%d%H%M%S")
outfile=${checksdir}/check.${datecode}.txt
if [[ -e "${outfile}" ]]; then
	echo "outfile ${outfile} already exists!"
	exit 1
fi

Nmissing=0
Nbadtimesteps=0
Nfiles=0
for gcm in ${gcms}; do
	gcm_lower=$(echo $3 | tr '[:upper:]' '[:lower:]') # Ensure lowercase
	. ./get_phase_from_gcm.sh
	for period in ${period_list}; do

		# Skip this period if it's not included for this GCM/reanalysis product
		if [[ ${phase} == "3a" && ( ${period} != "spinclim" && ${period} != "obsclim" && ${period} != "counterclim" ) ]]; then
			#			echo "Skipping bad combo: ${phase} ${period}"
			continue
		elif [[ ${phase} == "3b" && ( ${period} == "spinclim" || ${period} == "obsclim" || ${period} == "counterclim" ) ]]; then
			#			echo "Skipping bad combo: ${phase} ${period}"
			continue
		fi

		if [[ "${period}" == "picontrol" ]]; then
			for period_actual in picontrol historical ssp126 ssp370 ssp585; do
				echo "Checking ${gcm} ${period} (${period_actual})..."
				for v in ${var_list}; do
					Nfiles=$((Nfiles+1))
					do_check $gcm_lower $period $period_actual $v $check_timesteps $phase
					[[ ${result} == 0 ]] && Nmissing=$((Nmissing+1))
					[[ ${result} == 2 ]] && Nbadtimesteps=$((Nbadtimesteps+1))
				done
			done
		else
			echo "Checking ${gcm} ${period}..."
			for v in ${var_list}; do
				Nfiles=$((Nfiles+1))
				period_actual="xyz"
				do_check $gcm_lower $period $period_actual $v $check_timesteps $phase
				[[ ${result} == 0 ]] && Nmissing=$((Nmissing+1))
				[[ ${result} == 2 ]] && Nbadtimesteps=$((Nbadtimesteps+1))
			done
		fi
	done
done
echo "${Nmissing}/${Nfiles} files missing"
if [[ ${check_timesteps} == 1 ]]; then
	echo "${Nbadtimesteps}/$((Nfiles-Nmissing)) present files have bad timesteps"
else
	echo "(Did not check timesteps in files)"
fi




