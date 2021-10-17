#!/bin/bash

# Dump time variable to a file
ncdump_file=${checksdir}/.ncdump_${datecode}
ncdump -t -v time ${f} > ${ncdump_file}

# Get years that SHOULD be in file
y1=$(basename ${f} | grep -o -e "[0-9][0-9][0-9][0-9]" | head -n 1)
yN=$(basename ${f} | grep -o -e "[0-9][0-9][0-9][0-9]" | tail -n 1)

# Get and check first date in file
date1=$(grep "time = \"" ${ncdump_file} | grep -oE "[0-9]+-[0-9]+-[0-9]+" | head -n 1)
date1_target="${y1}-01-01"
if [[ "${date1}" != "${date1_target}" ]]; then
   if [[ ${badts} == 0 ]]; then
      badts=1
      echo ${f} >> ${outfile}
   fi
   echo "   ERROR: ${f} should begin ${date1_target} but begins ${date1}"
   echo "   ERROR: ${f} should begin ${date1_target} but begins ${date1}" >> ${outfile}
fi

# Get and check last date in file
dateN=$(tail -n 2 ${ncdump_file} | grep -oE "[0-9]+-[0-9]+-[0-9]+" | tail -n 1)
dateN_target="${yN}-12-31"
if [[ "${dateN}" != "${dateN_target}" ]]; then
   if [[ ${badts} == 0 ]]; then
      badts=1
      echo ${f} >> ${outfile}
   fi
   echo "   ERROR: ${f} should end ${dateN_target} but ends ${dateN}"
   echo "   ERROR: ${f} should end ${dateN_target} but ends ${dateN}" >> ${outfile}
fi

# Check number of timesteps
if [[ ${badts} == 0 ]]; then
   Ntimesteps=$(head ${ncdump_file} | grep -E "time = [0-9]+" | grep -oE "[0-9]+")
   if [[ "${Ntimesteps}" == "" ]]; then
      if [[ ${badts} == 0 ]]; then
         badts=1
         echo ${f} >> ${outfile}
      fi
      echo "   WARNING: Failed to parse number of timesteps"
      echo "   WARNING: Failed to parse number of timesteps" >> ${outfile}
   else
      # Calculate time between start and end dates (assuming leap years!)
      Ntimesteps_target=$(echo "( `date -d ${dateN_target} +%s` - `date -d ${date1_target} +%s`) / (24*3600)" | bc -l)
      Ntimesteps_target=$(printf "%.0f" $Ntimesteps_target) # Round
      Ntimesteps_target=$((Ntimesteps_target+1)) # Convert from time between to Ntimesteps
      if [[ "${Ntimesteps}" != "${Ntimesteps_target}" ]]; then
         if [[ ${badts} == 0 ]]; then
            badts=1
            echo ${f} >> ${outfile}
         fi
         echo "   ERROR: Should have ${Ntimesteps_target} timesteps but has ${Ntimesteps}"
         echo "   ERROR: Should have ${Ntimesteps_target} timesteps but has ${Ntimesteps}" >> ${outfile}
      fi
   fi
fi

if [[ ${badts} == 1 ]]; then
   anybad=1
fi
