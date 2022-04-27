#!/bin/bash

# Set up filenames
pushd ${gcmdir_orig} > /dev/null
set +e
file_in_list0=$(ls *_${var}_*.nc 2>/dev/null)
set -e
if [[ ${file_in_list0} == "" ]]; then
   echo "No files found matching ${gcmdir_orig}/*_${var}_*.nc"
   exit 1
fi

nfiles=0
for f in ${file_in_list0}; do
   file_in=$f

   # Skip if not in this period
   thisfile_y1=$(basename ${file_in} | grep -o -e "[0-9][0-9][0-9][0-9]" | head -n 1)
   thisfile_yN=$(basename ${file_in} | grep -o -e "[0-9][0-9][0-9][0-9]" | tail -n 1)
   if [[ ( ${thisfile_y1} -ge ${firstyear} && ${thisfile_y1} -le ${lastyear} ) || ( ${thisfile_yN} -ge ${firstyear} && ${thisfile_yN} -le ${lastyear} ) ]]; then
      file_in_list=("${file_in_list[@]}" ${file_in})
      nfiles=$((nfiles + 1))
   fi
   
   # Break if testing
   if [[ ${testing} -ne 0 && ${nfiles} -eq ${ntest} ]]; then
      break
   fi
done

file_generic=$(ls *_${var}_*.nc 2>/dev/null | head -n 1)
file_concat=${gcmdir_tmp}/$(echo ${file_generic} | sed "s@_[0-9][0-9][0-9][0-9]_@_${firstyear}_@")
file_concat=$(echo ${file_concat} | sed "s@_[0-9][0-9][0-9][0-9]\.nc@_${lastyear}.nc@")
file_nc4_big=$(echo ${file_concat} | sed "s@\.nc@.big.nc4@")
#file_nc4=$(echo ${file_nc4_big} | sed "s@.big@@")
file_nc4=${gcmdir_lpjg}/$(basename ${file_nc4_big} | sed "s@\.big@@")
popd > /dev/null

#echo $file_in_list0
#for f in ${file_in_list[@]}; do
#   echo $f
#done
#
#echo ${file_generic}
#echo ${file_concat}
#echo ${file_nc4_big}
#echo ${file_nc4}
#echo " "

