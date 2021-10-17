#!/bin/bash
set -e

if [[ "${period}" == "historical" || "${period_actual}" == "historical" ]]; then
   firstyear=1850
   lastyear=2014
elif [[ "${period}" == "ssp126" || "${period}" == "ssp370" || "${period}" == "ssp585" || "${period_actual}" == "ssp126" || "${period_actual}" == "ssp370" || "${period_actual}" == "ssp585" ]]; then
   firstyear=2015
   lastyear=2100
elif [[ "${period}" == "obsclim" || "${period}" == "counterclim" ]] ; then
   firstyear=1901
   lastyear=2016
elif [[ "${period}" == "spinclim" ]]; then
   firstyear=1801
   lastyear=1900
elif [[ "${period}" == "picontrol" ]]; then
   if [[ "${period_actual}" == "" ]]; then
      firstyear=1601
      lastyear=2100
   elif [[ "${period_actual}" == "picontrol" ]]; then
      firstyear=1601
      lastyear=1849
   elif [[ "${period_actual}" == "preind1" ]]; then
      firstyear=1601
      lastyear=1700
   elif [[ "${period_actual}" == "preind2" ]]; then
      firstyear=1701
      lastyear=1849
   else
      "get_years.sh: I don't know how to parse period==picontrol + period_actual==${period_actual}. Failing."
      exit 1
   fi
else
   if [[ ${period_actual} == "" ]]; then
      echo "get_years.sh: I don't know what years to use for period ${period} + undefined period_actual. Failing."
   else
      echo "get_years.sh: I don't know what years to use for period ${period} + period_actual ${period_actual}. Failing."
   fi
   exit 1
fi

