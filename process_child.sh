#!/bin/bash
set -e

###############################################################
# SUMMARY
#
# Converts GGCMI phase 3 climate forcing netCDFs to a single LPJ-GUESS-compatible netCDF, for a given combination of time period, GCM, and climate variable:
#   1. Re-chunks (for speed in LPJ-GUESS) and converts every GGCMI file into netCDF3-classic (for speed in this script).
#   2. Concatenates files.
#   3. Converts to netCDF4-classic and removes unlimited dimensions.
#   4. Deflates (compresses) to specified level.
#   5. For relative humidity: Adds a scaling factor for use in LPJ-GUESS, because LPJ-GUESS needs relative humidity in range [0,1] but GGCMI3 files use [0,100].
#
# Can be called independently or as part of process_parent.sh.
#
#
# USAGE
#
# process_child.sh $phase $period $gcm $period_actual $var $testing $deflate_lvl $gcmdir_orig [$ntest]
#
#    phase:   3a or 3b
#    period:  Period token for directory and file names.
#    gcm:     GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, or UKESM1-0-LL
#             (not case-sensitive)
#    period_actual:  Time period to process (e.g.: "historical"). Case-insensitive; will be converted to lowercase.
#    var:     Climate variable (e.g.: "pr")
#    testing: Any value other than 0 will prevent intermediate files from being deleted.
#    deflate_lvl: Level to which final file should be deflated (compressed). Range 0-9. See netCDF specification for more details.
#    gcmdir_orig: Directory containing the files before processing to LPJ-GUESS inputs.
#    ntest:   Set to the number of years you want to include in a test run of this script. Only required (and used) if testing!=0.
#
###############################################################


#module unload io/netcdf/4.4.2-rc1-intel-15.0.4-serial
#module load app/cdo/1.9.5
module load app/cdo/1.9.9
module load app/nco/4.7.8

module list

# Info for optimizing command parameters
#blocksize=16777216 # 16 MiB
oneMiB_in_bytes=1048576
if [[ "$SLURM_NNODES" == "" ]]; then
   nthreads=1
   availmem=$((1024 * oneMiB_in_bytes))
else
   #let "nthreads = $SLURM_NNODES * $SLURM_TASKS_PER_NODE"
   let "nthreads = $SLURM_JOB_CPUS_PER_NODE"
   availmem=$((SLURM_MEM_PER_NODE * oneMiB_in_bytes))
fi
partition="$SLURM_JOB_PARTITION"
if [[ "${partition}" == "" ]]; then
    partition="$SBATCH_PARTITION"
fi
echo "nthreads: ${nthreads}"
echo "availmem: ${availmem}"
echo "partition: ${partition}"

# Arguments: Phase, period, and GCM
phase=$1
if [[ "${phase}" != "3a" && "${phase}" != "3b" ]]; then
   echo "First argument (phase) must be either 3a or 3b, not '${phase}'"
   exit 1
fi
period=$2
if [[ "${period}" == "" ]]; then
   echo "You must provide an argument for period"
   exit 1
fi
gcm=$(echo $3 | tr '[:lower:]' '[:upper:]') # Ensure uppercase
if [[ "${gcm}" == "" ]]; then
   echo "You must provide an argument for gcm."
   exit 1
fi
period_actual=$4
if [[ "${period_actual}" == "" ]]; then
   echo "You must provide an argument for period_actual"
   exit 1
fi
var=$5
if [[ "${var}" == "" ]]; then
   echo "You must provide an argument for var."
   exit 1
fi
# If not 0, disables deletion of intermediate files
testing=$6
if [[ "${testing}" == "" ]]; then
   echo "You must provide an argument for testing."
   exit 1
fi
deflate_lvl=$7
if [[ "${deflate_lvl}" == "" ]]; then
   echo "You must provide an argument for deflate_lvl."
   exit 1
fi
# The directory where the file is located
gcmdir_orig="$8"
if [[ "${gcmdir_orig}" == "" ]]; then
   echo "You must provide an argument for gcmdir_orig."
   exit 1
fi
# If testing is anything other than zero: Only process the first ${ntest} subperiods.
ntest=$9
if [[ "${testing}" != 0 ]] && [[ "${ntest}" == "" ]]; then
   echo "You must provide an argument for ntest."
   exit 1
fi
# "clim" must be provided for 3a
clim=${10}
if [[ "${phase}" == "3a" ]] && [[ "${clim}" == "" ]]; then
   echo "You must provide an argument for clim when running process_child.sh for phase 3a."
   exit 1
fi
# Check for extra arguments
if [[ "${11}" != "" ]]; then
   echo "Too many arguments detected! Failing."
   exit 1
fi

# Set up
. ./get_dirnames.sh
start0=$(date +%s)

# (For purposes of building initial filelist only)
# What are all the years in this period?
. ./get_years.sh

date

# Set up filenames
. ./get_filenames.sh

for f in "${file_in_list[@]}"; do

   # Get path to file
   file_in=${gcmdir_orig}/$f
   if [[ ! -e ${file_in} ]]; then
      echo "file_in does not exist: ${file_in}"
      exit 1
   fi

   # Trim, if necessary
   thisfile_y1=$(basename ${file_in} | grep -o -e "[0-9][0-9][0-9][0-9]" | head -n 1)
   thisfile_yN=$(basename ${file_in} | grep -o -e "[0-9][0-9][0-9][0-9]" | tail -n 1)
   if [[ ${thisfile_y1} -lt ${firstyear} && ${thisfile_yN} -gt ${lastyear} ]]; then
      echo "thisfile_y1 (${thisfile_y1}) < ${firstyear} AND thisfile_yN (${thisfile_yN}) > ${lastyear}). This code can't handle that yet!"
      exit 1
   elif [[ ${thisfile_y1} -lt ${firstyear} || ${thisfile_yN} -gt ${lastyear} ]]; then
      if [[ ${thisfile_y1} -lt ${firstyear} ]]; then
         trimtxt="${firstyear}-${thisfile_yN}"
         file_trimmed=$(echo ${gcmdir_tmp}/${f} | sed "s@${thisfile_y1}@${firstyear}@")
         t1="${firstyear}-01-01"
         tN="${thisfile_yN}-12-31"
      elif [[ ${thisfile_yN} -gt ${lastyear} ]]; then
         trimtxt="${thisfile_y1}-${lastyear}"
         file_trimmed=$(echo ${gcmdir_tmp}/${f} | sed "s@${thisfile_yN}@${lastyear}@")
         t1="${thisfile_y1}-01-01"
         tN="${lastyear}-12-31"
      fi
      if [[ ! -e ${file_trimmed} ]]; then
         echo "      (Trimming ${thisfile_y1}-${thisfile_yN} to ${trimtxt}...)"
         ncks -O -d time,${t1},${tN} ${file_in} ${file_trimmed}
      fi
         
      file_in=${file_trimmed}
      trimmed_list="${trimmed_list} ${file_in}"
   fi

   # Save to list of files to concatenate
   path_in_list="${path_in_list} ${file_in}"

done # for f in ${file_in_list}
echo " "

# Concatenate.
# Notes:
### Bumping up block size doesn't have much of effect on speed.
### Increasing thread count doesn't have much effect on speed.
echo "Concatenating ($(date))..."
sleep 2
start=$(date +%s)
if [[ -e ${file_concat} ]]; then
   echo "(Removing existing file_concat: ${file_concat})"
   rm ${file_concat}
fi
cdo cat ${path_in_list} ${file_concat}
[[ ${testing} == 0 && ${trimmed_list} != "" ]] && rm ${trimmed_list}
end=$(date +%s)
diff=$(( $end - $start ))
diff0=$(( $end - $start0 ))
echo "$diff seconds ($diff0 seconds total)"
echo " "

# Re-chunk.
echo "Re-chunking ($(date))..."
sleep 2
ncks --bfr_sz ${availmem} -O --thr_nbr=${nthreads} -7 --cnk_plc=g3d --cnk_map=dmn --cnk_dmn=lon,1 --cnk_dmn=lat,1 ${file_concat} ${file_nc4_big}
[[ ${testing} == 0 ]] && rm ${file_concat}
end=$(date +%s)
diff=$(( $end - $start ))
diff0=$(( $end - $start0 ))
echo "$diff seconds ($diff0 seconds total)"
echo " "

# Remove unlimited dimensions and deflate
echo "Removing unlimited dimensions and deflating (level ${deflate_lvl}) ($(date))..."
sleep 2
start=$(date +%s)
nccopy -m ${availmem} -7 -d ${deflate_lvl} -s -u ${file_nc4_big} ${file_nc4}
[[ ${testing} == 0 ]] && rm ${file_nc4_big}
du -sh ${file_nc4}
end=$(date +%s)
diff=$(( $end - $start ))
diff0=$(( $end - $start0 ))
echo "$diff seconds ($diff0 seconds total)"
echo " "

# Need to add scaling factor for relative humidity
if [[ "${var}" == "hurs" ]]; then
   ncatted -a scale_factor,hurs,o,d,0.01 ${file_nc4}
fi

echo "All done"
date

exit 0
