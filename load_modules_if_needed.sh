if [[ $(printf %s\\n "$-") == *"e"* ]]; then
    e_set=1
    set +e
else
    e_set=0
fi

# Are modules needed?
cdo --help 1>/dev/null 2>&1
cdo_missing=$?
ncrename --help 1>/dev/null 2>&1
nco_missing=$?

# Load cdo module, if needed
if [[ ${cdo_missing} -ne 0 ]]; then
    module load app/cdo
fi
# Load nco module, if needed
if [[ ${nco_missing} -ne 0 ]]; then
    module load app/cdo
fi

if [[ ${e_set} -eq 1 ]]; then
    set -e
fi
