#!/bin/bash
#SBATCH -n 1
#SBATCH -p iojobs
#SBATCH -t 48:00:00
set -e

# Uploads climate files from Midway cluster, with an "automated kicking machine" to ensure that the transfer is restarted when the connection goes bad for some reason.

#############################################################################################
# Function-parsing code from https://gist.github.com/neatshell/5283811

script="upload_climate_3v2_akm.simple.sh"
#Declare the number of mandatory args
margs=1

# Common functions - BEGIN
function example {
echo -e "example: $script -s fhlr2 -t 10 -b 5M -x"
}

function usage {
echo -e "usage: $script -s SERVER [-t TIMEOUT -b MAXBANDWIDTH -x]\n"
}

clim_list="counterclim, obsclim, spinclim, transclim"
gcm_list="GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, UKESM1-0-LL"
period_list="3a: historical; 3b: picontrol, historical, ssp126, ssp370, ssp585"
reanalysis_list="GSWP3-W5E5, 20CRv3, 20CRv3-ERA5, 20CRv3-W5E5"
vars="hurs pr rsds sfcwind tas tasmax tasmin"

function help {
usage
echo -e "MANDATORY:"
echo -e "  -s, --server  VAL   The shortname of the server we'll be uploading to (fh, uc, or levante)"
echo -e "  -f, --phase  VAL   The ISIMIP phase whose forcings we'll be uploading (3a or 3b)"
echo -e "  -p, --period VAL   The period whose forcings we'll be uploading (${period_list})"
echo -e "MANDATORY for phase 3a (ignored for 3b):"
echo -e "  -c, --clim       VAL   The \"clim\" we'll be uploading (${clim_list})"
echo -e "  -r, --reanalysis VAL   The reanalysis product whose forcings we'll be uploading (${reanalysis_list})"
echo -e "MANDATORY for phase 3b (ignored for 3a):"
echo -e "  -g, --gcm        VAL   The global climate model whose forcings we'll be uploading (${gcm_list})"
echo -e "OPTIONAL:"
echo -e "  -x, --execute      Add this flag to actually start the upload instead of just doing a dry run."
echo -e "  -v, --vars    VAL  List of variables to include (default: \"${vars}\")"
echo -e "  -t, --timeout VAL  Timeout period for rsync (seconds). Default 15."
echo -e "  -b, --bwlimit VAL  Bandwidth limit. Default 10 MBps. Specify as number (KBps) or string with unit."
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
gcm=""
period=""

# Args while-loop
while [ "$1" != "" ];
do
	case $1 in
        -c  | --clim)  shift
            clim=$1
            ;;
        -f  | --phase )  shift
            phase_in=$1
            ;;
		-g  | --gcm)  shift
			gcm=$1
			;;
		-p  | --period)  shift
			period=$1
			;;
        -r  | --reanalysis)  shift
            reanalysis=$1
            ;;
		-s  | --server )  shift
			server=$1
			;;
		-v  | --vars )  shift
			vars="$1"
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

# Process options
lower () {
    echo "$1" | awk '{print tolower($0)}'
}
upper () {
    echo "$1" | awk '{print toupper($0)}'
}

# Phase 3a or 3b?
phase="$(lower "${phase_in}" | sed "s/3//")"
if [[ "${phase}" == "a" ]]; then
    phase="3a"
elif [[ "${phase}" == "b" ]]; then
    phase="3b"
elif [[ "${phase_in}" == "" ]]; then
    echo "You must specify -f/--phase (3)a or (3)b."
    exit 1
else
    echo "Phase ${phase_in} not recognized. Specify (3)a or (3)b."
    exit 1
fi

ending=
if [[ "${gcm}" != "" ]]; then
    if [[ "${phase}" == "3a" ]]; then
        echo "-g/--gcm ${gcm} ignored for phase 3a"
    else
        gcm="${gcm}*"
        ending="nc4"
    fi
fi
if [[ "${reanalysis}" != "" ]]; then
    reanalysis="$(lower ${reanalysis})"
    if [[ "${phase}" == "3b" ]]; then
        echo "-r/--reanalysis ${reanalysis} ignored for phase 3b"
    else
        reanalysis="${reanalysis}*"
        ending="nc4"
    fi
fi
if [[ "${clim}" != "" ]]; then
    clim="$(lower ${clim})"
    if [[ "${phase}" == "3b" ]]; then
        echo "-c/--clim ${clim} ignored for phase 3b"
    else
        clim="${clim}*"
        ending="nc4"
    fi
fi
if [[ "${period}" != "" ]]; then
    ending="nc4"
    if [[ "${phase}" == "3a" ]]; then
        . ./get_years.sh
        ending="${firstyear}_${lastyear}.nc4"
    elif [[ "${phase}" == "3b" ]]; then
        period="${period}*"
    fi
fi
if [[ "${ending}" != "" ]]; then
    if [[ "${phase}" == "3a" ]]; then
        beginning="${reanalysis}${clim}"
    elif [[ "${phase}" == "3b" ]]; then
        beginning="${gcm}${period}"
    fi
else
    beginning="*"
    ending="nc4"
fi
for v in ${vars}; do
    incl_var_list="${incl_var_list} --include=${beginning}_${v}_*${ending}"
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
elif [[ "${server}" == "levante" ]]; then
	remote_dir_top="/home/b/b380566/ISIMIP3/climate_land_only_v2"
elif [[ "${server}" == "uc" ]]; then
	remote_dir_top="/pfs/work7/workspace/scratch/lr8247-isimip3_climatev2"
else
	echo "server ${server} not recognized"
	exit 1
fi

# Create that directory, if needed
ssh ${server} mkdir -p "${remote_dir_top}"

if [[ "${phase}" == "3a" ]]; then
    otherphase="3b"
elif [[ "${phase}" == "3b" ]]; then
    otherphase="3a"
fi
transfertxt="${incl_var_list} --exclude=climate${otherphase}/ --include=**/ --exclude=* * ${server}:${remote_dir_top}/"

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

