#!/bin/bash
#SBATCH -n 1
#SBATCH -p iojobs
#SBATCH -t 48:00:00
set -e

# Downloads climate files from Levante cluster, with an "automated kicking machine" to ensure that the transfer is restarted when the connection goes bad for some reason.

#############################################################################################
# Function-parsing code from https://gist.github.com/neatshell/5283811

script="download_climate_3v2_akm_withocean.sh"
#Declare the number of mandatory args
margs=2

# Common functions - BEGIN
function example {
echo -e "example: $script -f 3a -p historical -c obsclim -r GSWP3-W5E5 -t 10 -b 5M -x"
}

function usage {
echo -e "usage 3a: $script -f ISIMIP_PHASE -p PERIOD -c CLIM -r REANALYSIS -t TIMEOUT -b BANDWIDTH_LIMIT -x"
echo -e "usage 3b: $script -f ISIMIP_PHASE -p PERIOD -g gcm -t TIMEOUT -b BANDWIDTH_LIMIT -x"
}

clim_list="counterclim, obsclim, spinclim, transclim"
gcm_list="GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, UKESM1-0-LL"
period_list="3a: historical; 3b: picontrol, historical, ssp126, ssp370, ssp585"
reanalysis_list="GSWP3-W5E5, 20CRv3, 20CRv3-ERA5, 20CRv3-W5E5"
vars="hurs pr rsds sfcwind tas tasmax tasmin"
fileext=".nc"

function help {
usage
echo -e "MANDATORY:"
echo -e "  -f, --phase  VAL   The ISIMIP phase whose forcings we'll be downloading (3a or 3b)"
echo -e "  -p, --period VAL   The period whose forcings we'll be downloading (${period_list})"
echo -e "MANDATORY for phase 3a (ignored for 3b):"
echo -e "  -c, --clim       VAL   The \"clim\" we'll be downloading (${clim_list})"
echo -e "  -r, --reanalysis VAL   The reanalysis product whose forcings we'll be downloading (${reanalysis_list})"
echo -e "MANDATORY for phase 3b (ignored for 3a):"
echo -e "  -g, --gcm        VAL   The global climate model whose forcings we'll be downloading (${gcm_list})"
echo -e "OPTIONAL:"
echo -e "  -x, --execute      Add this flag to actually start the upload instead of just doing a dry run."
echo -e "  -v, --vars    VAL  List of variables to include (default: \"${vars}\")"
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
execute=0
timeout=15
bwlimit="10M"
gcm=""
period=""
phase_in=""
clim=""
reanalysis=""

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

# Period must be specified
if [[ "${period}" == "" ]]; then
    echo "You must specify a period with -p/--period (${period_list})"
    exit 1
fi

# GCM or reanalysis product, and paths
if [[ "${phase}" == "3a" ]]; then
    if [[ "${gcm}" != "" ]]; then
        echo "-g/--gcm ${gcm} is ignored for phase 3a"
    fi
    if [[ "${reanalysis}" == "" ]]; then
        echo "For phase 3a, you must specify a reanalysis product with -r/--reanalysis (e.g., ${reanalysis_list})"
        exit 1
    fi
    if [[ "${clim}" == "" ]]; then
        echo "For phase 3a, you must specify -c/--clim (e.g., ${clim_list})"
        exit 1
    fi
    # Where will the files be on the remote?
    remote_dir=/work/bb0820/ISIMIP/ISIMIP3a/InputData/climate/atmosphere/${clim}/global/daily/${period}/${reanalysis}
    
    # Where will we be downloading to?
    local_dir=climate3a/${period}/${clim}/${reanalysis}-withocean
elif [[ "${phase}" == "3b" ]]; then
    if [[ "${clim}" != "" ]]; then
        echo "-c/--clim ${} is ignored for phase 3b"
    fi
    if [[ "${reanalysis}" != "" ]]; then
        echo "-r/--reanalysis ${reanalysis} is ignored for phase 3b"
    fi
    if [[ "${gcm}" == "" ]]; then
        echo "For phase 3b, you must specify a gcm product with -g/--gcm (e.g., ${gcm_list})"
        exit 1
    fi
    # Where will the files be on the remote?
    remote_dir=/work/bb0820/ISIMIP/ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/${period}/${gcm}
    
    # Where will we be downloading to?
    local_dir=climate3b/${period}/${gcm}-withocean
fi
mkdir -p "${local_dir}"

# Make sure GCM name is uppercase
#gcm=$(echo "$gcm" | tr '[:upper:]' '[:lower:]')
gcm=$(echo "$gcm" | tr '[:lower:]' '[:upper:]')


# Get list of includes
include_list=""
for v in ${vars}; do
    include_list="${include_list} --include=*_${v}_*"
done
include_list="--include=*_hurs_* --include=*_pr_* --include=*_rsds_* --include=*_sfcwind_* --include=*_tas_* --include=*_tasmax_* --include=*_tasmin_*"

if [[ ${execute} -eq 0 ]]; then
   rsync -ahm --dry-run -v --info=progress2 --ignore-existing  ${include_list} --include="**/" --exclude="*" levante:${remote_dir} ${local_dir}
   echo " "
   echo "Dry run. To actually download, type anything for a third argument."
else
    transfertxt="${include_list} --exclude="*" levante:${remote_dir}/"*" ${local_dir}/"
    # Do we need to rsync this file? This does a dry run and counts the number of files that would be transferred.
    notdoneyet=$(rsync -avtn --prune-empty-dirs --ignore-existing  ${transfertxt} | grep $fileext | wc -l)
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
          rsync --prune-empty-dirs -av -h --info=progress2 --timeout=$timeout --bwlimit=$bwlimit --ignore-existing  ${transfertxt}
          result=$?
          if [[ $result -eq 30 ]]; then
            theproblem=timeout
            echo $theproblem
          elif [[ $result -gt 0 ]]; then
            theproblem="error $result"
            echo $theproblem
          fi
          set -e
          notdoneyet=$(rsync -avtn --prune-empty-dirs --ignore-existing  ${transfertxt} | grep $fileext | wc -l)
       done
       echo Done with $d
    else
       echo Skipping $d
    fi
fi

exit 0

