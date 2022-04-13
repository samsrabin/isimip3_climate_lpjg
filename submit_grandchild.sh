#!/bin/bash

echo "Will process ${thisid} (${partition_submit}, ${childmem_submit}B RAM)"

if [[ ${justlist} == 0 ]]; then
   # Replace DEPENDENCY placeholder
   thecommand=$(echo ${thecommand} | sed "s/DEPENDENCY/${dependency}/")
   
   # Specify logfile
   logfile=${gcmdir_logs}/${thisid}.$(date "+%Y%m%d%H%M%S").log
   
   # Submit job, saving ID as $thisJob
   thisJob=$(${thecommand})
   thisJob=$(echo $thisJob | sed "s/Submitted batch job //")
   echo "   Submitted batch job ${thisJob}"
   if [[ ${dependency} != "" ]]; then
      echo "   dependency: ${dependency}"
   fi
   
   # Update dependency, requiring jobs to run serially
   dependency="-d ${depend_after}:${thisJob}"
fi

