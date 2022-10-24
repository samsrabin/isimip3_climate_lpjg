#!/usr/bin/env bash
#SBATCH -n 1
#SBATCH -p iojobs
#SBATCH -t 24:00:00
set -e

this_dir="$1"
if [[ "${this_dir}" == "" ]]; then
    echo "You must provide this_dir"
    exit 1
elif [[ ! -e "${this_dir}" ]]; then
    echo "this_dir (${this_dir}) does not exist!"
    exit 1
fi

cd "${this_dir}"

thisclim="$(basename "${this_dir}" | sed "s/-lpjg//")"
thisperiod="$(basename "$(dirname "${this_dir}")")"
out_dir="CMIP6_BC_climate/${thisclim}/${thisperiod}"

rclone mkdir dropbox:"${out_dir}"
for f in *; do
    rclone copy -P "${f}" dropbox:"${out_dir}"
done

exit 0
