#!/bin/bash
#SBATCH --mem 32G
#SBATCH -p sandy
#SBATCH -t 24:00:00
#SBATCH -n 1
module load app/cdo

# Based on Christoph's script at https://ebi-forecast.igb.illinois.edu/ggcmi/issues/357

unmasked_dir="$1"
if [[ "${unmasked_dir}" == "" ]]; then
    echo "You must provide unmasked_dir"
    exit 1
elif [[ ! -e "${unmasked_dir}" ]]; then
    echo "unmasked_dir (${unmasked_dir}) does not exist!"
    exit 1
fi
masked_dir="${unmasked_dir/-withocean/}"
mkdir -p "${masked_dir}"
tmp="${masked_dir}/tmp.nc"

cd "${unmasked_dir}"

for unmasked_file in *.nc; do
    masked_file="${masked_dir}/${unmasked_file}"
    if [[ -e "${masked_file}" ]]; then
        echo "$(basename "${masked_file}") already processed; skipping."
        continue
    fi
    echo ${unmasked_file}
    
    # reducegrid creates an unstructured output file, i.e. geographic information is lost. :(
    #cdo -f nc4c -z zip_6 reducegrid,/project2/ggcmi/AgMIP.input/phase3/raw_ISIMIP/landseamask/landseamask.nc ${unmasked_file} intermediate.nc
    
    # workaround from https://stackoverflow.com/questions/39058260/create-a-netcdf-file-with-data-masked-to-retain-land-points-only
    # (About 4 minutes per file on sandy)
    cdo -z zip_6 div "${unmasked_file}" /pd/data/lpj/sam/ISIMIP3/inputs/seamask.nc "${tmp}"

    mv "${tmp}" "${masked_file}"
    rm "${unmasked_file}"
done

exit 0
