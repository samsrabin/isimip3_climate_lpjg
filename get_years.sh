#!/bin/bash
set -e

if [[ "${phase}" == "3a" ]]; then
    if [[ "${clim}" == "obsclim"* || "${clim}" == "counterclim"* ]] ; then
       firstyear=1901
       lastyear=2019
    elif [[ "${clim}" == "spinclim"* ]]; then
       firstyear=1801
       lastyear=1900
    elif [[ "${clim}" == "transclim"* ]]; then
       firstyear=1851
       lastyear=1900
    else
       echo "clim '${clim}' not recognized in get_years.sh"
       exit 1
    fi
elif [[ "${phase}" == "3b" ]]; then
    if [[ "${period}" == "historical" || "${period_actual}" == "historical" ]]; then
       firstyear=1850
       lastyear=2014
    elif [[ "${period}" == "ssp"* || "${period_actual}" == "ssp"* ]]; then
       firstyear=2015
       lastyear=2100
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
else
    echo "Phase '${phase}' not recognized in get_years.sh."
    exit 1
fi
