#!/bin/bash
#SBATCH -p sandy
#SBATCH -n 1
#SBATCH -t 72:00:00
#SBATCH -o logs/upload.%A.out 

./upload_climate_3v2_akm.simple.sh -s mistral -x

exit 0
