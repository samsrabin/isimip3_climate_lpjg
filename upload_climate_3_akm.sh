#!/bin/bash
set -e

# Uploads climate files from Midway cluster, with an "automated kicking machine" to ensure that the transfer is restarted when the connection goes bad for some reason.

#############################################################################################
# Function-parsing code from https://gist.github.com/neatshell/5283811

script="upload_climate_3_akm.sh"
#Declare the number of mandatory args
margs=2

subperiod_list_all="preind1 preind2 picontrol historical ssp126" # Only need one ssp* to get future subperiod

# Common functions - BEGIN
function example {
echo -e "example: $script -s fhlr2 -g GFDL-ESM4 -p \"picontrol historical\" -t 10 -b 5M -x"
}

function usage {
echo -e "usage: $script -s SERVER -g GCM_OR_REANALYSIS [-p "PERIOD1 PERIOD2" -t TIMEOUT -b MAXBANDWIDTH -x]\n"
}

function help {
usage
echo -e "MANDATORY:"
echo -e "  -s, --server  VAL   The shortname of the server we'll be uploading to (fh, uc, or mistral)"
echo -e "  -g, --gcm  VAL  The GCM (3b) or reanalysis product (3a) to upload. One of: GSWP3, GSWP3-W5E5, GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, or UKESM1-0-LL.\n"
echo -e "OPTIONAL:"
echo -e "  -x, --execute Add this flag to actually start the upload instead of just doing a dry run."
echo -e "  -p, --periods VAL  Space-separated list of periods to upload. Default is all periods for the phase associated with the given GCM or reanalysis product."
echo -e "  -u, --subperiods VAL  Space-separated list of picontrol subperiods to upload. Default is all: \"${subperiod_list_all}\""
echo -e "  -v, --variables VAL  Space-separated list of climate variables to upload. Default is all: \"hurs pr rsds sfcwind tas tasmax tasmin\""
echo -e "  -t, --timeout VAL  Timeout period for rsync (seconds). Default 15."
echo -e "  -b, --bwlimit VAL  Bandwidth limit. Default 10 MBps. Specify as number (KBps) or string with unit."
echo -e "  -i, --include_extra VAL  Extra text to include at beginning of includes/excludes list."
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
server=
gcm=
execute=0
period_list=""
subperiod_list="${subperiod_list_all}"
var_list="hurs pr rsds sfcwind tas tasmax tasmin"
timeout=15
bwlimit="10M"
include_extra=""

# Args while-loop
while [ "$1" != "" ];
do
	case $1 in
		-s  | --server )  shift
			server=$1
			;;
		-g  | --gcm )  shift
			gcm=$1
			;;
		-x  | --execute  )  execute=1
			;;
		-p  | --periods )  shift
			period_list=$1
			;;
		-u  | --subperiods )  shift
			subperiod_list=$1
			;;
		-v  | --variables)  shift
			var_list=$1
			;;
		-t  | --timeout)  shift
			timeout=$1
			;;
		-b  | --bwlimit)  shift
			bwlimit=$1
			;;
		-i  | --include_extra)  shift
			include_extra=$1
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
margs_check $server $gcm

# End function-parsing code
#############################################################################################

fileext=".nc4"

# Ensure only one GCM specified
ngcm=$(echo $gcm | wc -w)
if [[ "${ngcm}" -ne 1 ]]; then
	echo "Must specify exactly 1 gcm (not ${ngcm})"
	exit 1
fi

# Ensure correct-case GCMs
gcm=$(echo "$gcm" | tr '[:upper:]' '[:lower:]')
gcm_upper=$(echo "$gcm" | tr '[:lower:]' '[:upper:]')

# Parse phase from GCM
. ./get_phase_from_gcm.sh

# If period list not provided, use entire set of periods for given phase
if [[ "${period_list}" == "" ]]; then
	if [[ "${phase}" == "3a" ]]; then
		period_list="obsclim spinclim counterclim"
	elif [[ "${phase}" == "3b" ]]; then
		period_list="picontrol historical ssp126 ssp370 ssp585"
	else
		echo "Phase ${phase} not recognized!"
	fi
fi

# Ensure lowercase period list
period_list=$(echo "$period_list" | tr '[:upper:]' '[:lower:]')

# Where will the files be on the remote?
if [[ "${server}" == "unicluster" ]]; then
	server="uc"
fi
if [[ "${server}" == "fhlr2" ]] || [[ "${server}" == "fh2" ]] || [[ "${server}" == "fh" ]]; then
	remote_dir_top="/home/fh2-project-lpjgpi/lr8247/ggcmi/phase3/ISIMIP3/climate_land_only_v2"
elif [[ "${server}" == "mistral" ]]; then
	remote_dir_top="/scratch/b/b380566/ISIMIP3/climate_land_only_v2"
elif [[ "${server}" == "uc" ]]; then
	remote_dir_top="/pfs/work7/workspace/scratch/lr8247-isimip3_climate-0"
else
	echo "server ${server} not recognized"
	exit 1
fi

# Create that directory, if needed
ssh ${server} mkdir -p "${remote_dir_top}"

# Build list of patterns to include
include_list="${include_extra} --exclude=*.nc4.*"
nvars=$(echo $var_list | wc -w)
for v in $var_list; do
	nv_done=$((nv_done+1))
	for period in $period_list; do
		if [[ ${phase} == "3a" ]]; then
			include_list="${include_list} --include=${gcm}_${period}_${v}_*"
		elif [[ ${phase} == "3b" ]]; then

			# If including picontrol, include only those subperiods specified in subperiod_list.
			if [[ ${period} == "picontrol" ]]; then
				for period_actual in ${subperiod_list_all}; do
					. ./get_years.sh
					inclexcltext="--exclude=${gcm}_*_w5e5_${period}_${v}_*_${firstyear}_${lastyear}*"
					for u in ${subperiod_list}; do
						if [[ $u == $period_actual ]]; then
							inclexcltext=$(echo ${inclexcltext} | sed "s/ex/in/")
							break
						fi
					done
					include_list="${include_list} ${inclexcltext}"
				done
				include_list="${include_list} --exclude=${gcm}_*_w5e5_${period}_${v}_*"
				period_actual=

			# If not picontrol, include only the actual period's files, and not any subsets.
			else
				. ./get_years.sh
				include_list="${include_list} --include=${gcm}_*_w5e5_${period}_${v}_*_${firstyear}_${lastyear}*"
				if [[ ${nv_done} == ${nvars} ]]; then
					include_list="${include_list} --exclude=${gcm}_*_w5e5_${period}_*"
				fi
			fi
		else
			echo "Phase ${phase} not recognized when building include_list"
			exit 1
		fi

	done

done

transfertxt="${include_list} --include=climate${phase}/*/${gcm_upper}-lpjg/ --include=climate${phase}/*/ --include=climate${phase}/ --exclude=* . ${server}:${remote_dir_top}"

if [[ ${execute} -eq 0 ]]; then
	rsync -ah --dry-run -v --stats --partial --prune-empty-dirs ${transfertxt}
	echo " "
	echo "Dry run. To actually upload, add -x flag."
else
	# Do we need to rsync this file? This does a dry run and counts the number of files that would be transferred.
	notdoneyet=$(rsync -avtn --prune-empty-dirs --partial ${transfertxt} | grep $fileext | wc -l)
	ntries=0
	theproblem=" "

	if [[ ${notdoneyet} -gt 0 ]]; then
		echo Starting $d
		while [[ ${notdoneyet} -gt 0 ]]; do
			ntries=$((ntries+1))
			if [[ ${ntries} -gt 1 ]]; then
				echo "Starting try ${ntries} (${theproblem})"
			fi
			set +e
			rsync --prune-empty-dirs -a -v -h --info=progress2 --timeout=$timeout --bwlimit=$bwlimit --inplace ${transfertxt}
			result=$?
			if [[ $result -eq 30 ]]; then
				theproblem=timeout
				echo $theproblem
			elif [[ $result -gt 0 ]]; then
				theproblem="error $result"
				echo $theproblem
			fi
			set -e
			notdoneyet=$(rsync -avtn --prune-empty-dirs --partial ${transfertxt} | grep $fileext | wc -l)
		done
		echo Done with $d
	else
		echo Skipping $d
	fi
fi

exit 0

