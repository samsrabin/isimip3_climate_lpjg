#!/bin/bash
set -e

# Uploads climate files from Midway cluster, with an "automated kicking machine" to ensure that the transfer is restarted when the connection goes bad for some reason.

#############################################################################################
# Function-parsing code from https://gist.github.com/neatshell/5283811

script="upload_climate_3v2_akm.simple.sh"
#Declare the number of mandatory args
margs=1

subperiod_list_all="preind1 preind2 picontrol historical ssp126" # Only need one ssp* to get future subperiod

# Common functions - BEGIN
function example {
echo -e "example: $script -s fhlr2 -t 10 -b 5M -x"
}

function usage {
echo -e "usage: $script -s SERVER [-t TIMEOUT -b MAXBANDWIDTH -x]\n"
}

function help {
usage
echo -e "MANDATORY:"
echo -e "  -s, --server  VAL   The shortname of the server we'll be uploading to (fh, uc, mistral, or levante)"
echo -e "OPTIONAL:"
echo -e "  -x, --execute Add this flag to actually start the upload instead of just doing a dry run."
echo -e "  -t, --timeout VAL  Timeout period for rsync (seconds). Default 15."
echo -e "  -b, --bwlimit VAL  Bandwidth limit. Default 10 MBps. Specify as number (KBps) or string with unit."
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
execute=0
timeout=15
bwlimit="10M"

# Args while-loop
while [ "$1" != "" ];
do
	case $1 in
		-s  | --server )  shift
			server=$1
			;;
		-x  | --execute  )  execute=1
			;;
		-t  | --timeout)  shift
			timeout=$1
			;;
		-b  | --bwlimit)  shift
			bwlimit=$1
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

# Where will the files be on the remote?
if [[ "${server}" == "unicluster" ]]; then
	server="uc"
fi
if [[ "${server}" == "fhlr2" ]] || [[ "${server}" == "fh2" ]] || [[ "${server}" == "fh" ]]; then
	remote_dir_top="/home/fh2-project-lpjgpi/lr8247/ggcmi/phase3/ISIMIP3/climate_land_only_v2"
elif [[ "${server}" == "mistral" ]]; then
	remote_dir_top="/scratch/b/b380566/ISIMIP3/climate_land_only_v2"
elif [[ "${server}" == "levante" ]]; then
	remote_dir_top="/home/b/b380566/ISIMIP3/climate_land_only_v2"
elif [[ "${server}" == "uc" ]]; then
	remote_dir_top="/pfs/work7/workspace/scratch/lr8247-isimip3_climate-0/climate_land_only_v2"
else
	echo "server ${server} not recognized"
	exit 1
fi

# Create that directory, if needed
ssh ${server} mkdir -p "${remote_dir_top}"

transfertxt="--include=*sh --include=*nc4 --include=*/*-lpjg/ --include=*/*/ --include=*/ --exclude=* * ${server}:${remote_dir_top}/"
#transfertxt="--include=mri*picontrol*nc4 --include=*/*-lpjg/ --include=*/*/ --include=*/ --exclude=* * ${server}:${remote_dir_top}/"

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

