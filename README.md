# Processing ISIMIP3 climate forcings for LPJ-GUESS

## Setup

### My git repo

Clone my [`isimip3_climate_lpjg`](https://github.com/samsrabin/isimip3_climate_lpjg) git repo to somewhere on Unicluster, and add it to your path.

```bash
git clone git@github.com:samsrabin/isimip3_climate_lpjg.git
```

### Environment variables

Create a folder (on Unicluster, a workspace) for all your ISIMIP3 climate files to go into, and add the following lines to your `~/.bash_profile`:

```bash
export ISIMIP3_CLIMATE_DIR="/path/to/your/isimip3climate/workspace"
export ISIMIP3_CLIMATE_PROCESSING_QUEUE=cluster_specific_queue
```

where `cluster_specific_queue` is `single` for Unicluster. I'm not sure which queue would be best for Owl.

### Supporting files

Make sure to copy my `misc/` directory on Unicluster (`/pfs/work7/workspace/scratch/xg4606-isimip3_climatev2_202305/misc`) to your `${ISIMIP3_CLIMATE_DIR}/`.

### Levante

We will download the raw ISIMIP3 climate files from the server ISIMIP uses, Levante. This is run by the DKRZ; you can get a user account with the instructions [here](https://docs.dkrz.de/doc/getting_started/getting-a-user-account/dkrz-user-account.html#dkrz-user-account). Make sure to use your KIT address, and request to be added to the project "ISI-MIP Inter-Sectoral Impact Model Intercomparison Project" (PID 820). Once that's done, set up an item for Levante in your `~/.ssh/config` like so:

```
Host levante
    Hostname levante.dkrz.de
    User your_username_here
```

Downloads are long-running jobs that we'll want to submit using Slurm, so you won't be able to enter your password. Use `ssh-keygen` to [generate an SSH key](https://docs.oracle.com/en/cloud/cloud-at-customer/occ-get-started/generate-ssh-key-pair.html) for use with Levante and add a line for it (not the `.pub` file) like so:

```
Host levante
    Hostname levante.dkrz.de
    User your_username_here
    IdentityFile ~/.ssh/name_of_ssh_key
```

Then you need to [register the key with DKRZ](https://docs.dkrz.de/doc/levante/access-and-environment.html). If this has all worked, you should be able to `ssh levante` and log in without having to add your password (or maybe it'll require your password one last time). 



## Unicluster: Installing required software

- Make sure `~/software` exists and is on your path.
- Note that, after installing, these utilities will only work when you have the gnu netcdf module loaded. They won't work with Intel. (If you have the Intel netcdf module loaded and you call a *script* that loads the gnu netcdf and then uses these utilities, that's fine.)

(This wasn't necessary on keal as these utilities were available as modules; not sure about owl.)

### `cdo` utilities

```bash
module purge
module load lib/netcdf/4.9.0-gnu-12.1-openmpi-4.1

cd ~/software
wget https://code.mpimet.mpg.de/attachments/download/28013/cdo-2.2.0.tar.gz
tar -xzf cdo-2.2.0.tar.gz

cd cdo-2.2.0/
./configure --prefix="$HOME/software" --with-netcdf=/opt/bwhpc/common/lib/netcdf/4.9.0-gnu-12.1-openmpi-4.1
/usr/bin/make
/usr/bin/make install
```



### `UDUNITS` (probably not necessary)

```bash
cd ~/software
wget https://downloads.unidata.ucar.edu/udunits/2.2.28/udunits-2.2.28.tar.gz
tar -xzf udunits-2.2.28.tar.gz
cd udunits-2.2.28/

./configure --prefix="$HOME/software"
/usr/bin/make
/usr/bin/make install
```



### `nco` utilities

```bash
module purge
module load lib/netcdf/4.9.0-gnu-12.1-openmpi-4.1

cd ~/software
git clone https://github.com/nco/nco.git
cd nco
git checkout 4.9.9

./configure --prefix="$HOME/software" NETCDF_ROOT=/opt/bwhpc/common/lib/netcdf/4.9.0-gnu-12.1-openmpi-4.1
/usr/bin/make
/usr/bin/make install
```



## What forcings are available?

On Levante, the forcings are at the following path for [ISIMIP3a](https://protocol.isimip.org/#ISIMIP3a/agriculture): 

````
/work/bb0820/ISIMIP/ISIMIP3a/InputData/climate/atmosphere/${clim}/global/daily/historicalgg/${reanalysis}
````

where:

- `clim` can be `obsclim` (observed climate), `counterclim` (counterfactual climate—no global warming—for use in attribution experiments), `spinclim` (the first 100 years of `counterclim`, for use in spinup), and `transclim` (for use in 1850-1900)
- `reanalysis` can be `GSWP3-W5E5`, `20CRv3`, `20CRv3-ERA5`,  or`20CRv3-W5E5`

And for [ISIMIP3b](https://protocol.isimip.org/#ISIMIP3b/agriculture):

```
/work/bb0820/ISIMIP/ISIMIP3b/${Nary}/climate/atmosphere/bias-adjusted/global/daily/${period}/${gcm}
```

where:

- `Nary` can be `InputData` or `SecondaryInputData` (see below)
- `period` can be `picontrol`, `historical`, `ssp126`/`ssp370`/`ssp585` (for both values of `Nary`), or various other periods/scenarios for `SecondaryInputData`.
- `gcm` for both values of `Nary` can be `GFDL-ESM4`,` IPSL-CM6A-LR`, `MPI-ESM1-2-HR`, `MRI-ESM2-0`, `UKESM1-0-LL`; `SecondaryInputData` has others. Those 5 are the only I've processed so far.



## Using the scripts

### Downloading the raw forcings

The script `download_climate_3v2_akm_withocean.sh` is pretty flexible. Try doing `download_climate_3v2_akm_withocean.sh -h` for instructions. 

Here are some examples. I've left off the `-x/--execute` argument which would actually download the files, so you can run these in an interactive terminal and it'll just list the files that would be downloaded. If you want to actually download (not these; I've already processed them), prepend `sbatch -p ${ISIMIP3_CLIMATE_PROCESSING_QUEUE}` and append `-x`.

Download the ISIMIP3a `obsclim` forcings from GSWP3-W5E5:

```bash
download_climate_3v2_akm_withocean.sh -f 3a -c obsclim -r GSWP3-W5E5
```

Download the ISIMIP3b forcings for SSP5-85 from GFDL-ESM4:

```bash
download_climate_3v2_akm_withocean.sh -f 3b -p ssp585 -g GFDL-ESM4
```

Download the ISIMIP3b forcings for SSP2-45 from GFDL-ESM4, except for relative humidity (`hurs`), which was previously unavailable. We add `-2` because it's a secondary scenario:

```bash
download_climate_3v2_akm_withocean.sh -f 3b -2 -p ssp245 -g GFDL-ESM4 -v "pr rsds sfcwind tas tasmax tasmin"
```



### Removing the oceans

We don't need all the ocean cells, so we can remove them. 

```bash
sbatch -p ${ISIMIP3_CLIMATE_PROCESSING_QUEUE} remove_oceans.sh /path/to/whatever/you/just/downloaded-withocean
```





### Converting to LPJ-GUESS format

This is done with the `process_parent.sh` script, which submits a series of Slurm jobs to do the processing. You can see what you will be processing like so:

```bash
process_parent.sh GFDL-ESM4 -p ssp245 -v "pr rsds sfcwind tas tasmax tasmin"
```

To actually submit the jobs, just append `-x`. The script will automatically submit the jobs using `sbatch -p $ISIMIP3_CLIMATE_PROCESSING_QUEUE`.
