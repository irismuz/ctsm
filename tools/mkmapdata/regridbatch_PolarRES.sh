#!/bin/bash
#
#
# Batch script to submit to create mapping files for all standard
# resolutions.  If you provide a single resolution via "$RES", only
# that resolution will be used. In that case: If it is a regional or
# single point resolution, you should set '#PBS -n' to 1, and be sure
# that '-t regional' is specified in cmdargs.
#
###SBATCH --account=nn8002k 
###SBATCH --job-name=mkmapdata
###SBATCH --mem-per-cpu=124G
###SBATCH --ntasks=1
###SBATCH --time=03:00:00

#SBATCH --account=nn8002k --job-name=regridbatch
#SBATCH --partition=preproc
#SBATCH --qos=preproc
#SBATCH --time=03:00:00
#SBATCH --ntasks=1 --cpus-per-task=1
#SBATCH --mem-per-cpu=500G

#source /cluster/bin/jobsetup #from Gunnar
#module load ESMF/8.1.1-foss-2021a #from Gunnar
#module load NCO/5.0.1-foss-2021a  #from Gunnar
#module load NCL/6.6.2-foss-2021a  #from Gunnar

module --force purge #from Mariana
module load StdEnv #from Mariana

#One option (does not include the necessary NCO module)
#module use /cluster/shared/noresm/eb_mods/modules/all #from Mariana
#ml ESMF/8.4.1-iomkl-2021b-ParallelIO-2.5.10 #from Mariana
#ml CMake/3.21.1-GCCcore-11.2.0
#ml JasPer/2.0.33-GCCcore-11.2.0
#ml libpng/1.6.37-GCCcore-11.2.0
#ml FlexiBLAS/3.0.4-GCC-11.2.0

#Another option
ml NCO/5.1.9-iomkl-2022a
ml CMake/3.23.1-GCCcore-11.3.0
ml JasPer/2.0.33-GCCcore-11.3.0
ml libpng/1.6.37-GCCcore-11.3.0
ml FlexiBLAS/3.2.0-GCC-11.3.0

export ESMF_NETCDF_LIBS="-lnetcdff -lnetcdf -lnetcdf_c++"
#export ESMF_DIR=/usit/abel/u1/huit/ESMF/esmf
export ESMF_COMPILER=intel
export ESMF_COMM=openmpi
#export ESMF_NETCDF="test"
#export ESMF_NETCDF_LIBPATH=/cluster/software/ESMF/8.2.0-foss-2021b/lib
#export ESMF_NETCDF_INCLUDE=/cluster/software/ESMF/8.2.0-foss-2021b/include
#export ESMF_NETCDF_LIBPATH=/cluster/shared/noresm/eb_mods/software/ESMF/8.4.1-iomkl-2021b-ParallelIO-2.5.10/lib
#export ESMF_NETCDF_INCLUDE=/cluster/shared/noresm/eb_mods/software/ESMF/8.4.1-iomkl-2021b-ParallelIO-2.5.10/include

ulimit -s unlimited

#export ESMFBIN_PATH=/cluster/software/ESMF/8.2.0-foss-2021b/bin
#export ESMFBIN_PATH=/cluster/shared/noresm/eb_mods/software/ESMF/8.4.1-iomkl-2021b-ParallelIO-2.5.10/bin
export ESMFBIN_PATH=${EBROOTESMF}/bin
export CSMDATA=/cluster/shared/noresm/inputdata
#export MPIEXEC=mpirun
export MPIEXEC=srun

RES=1x1 #used for default runs
#RES="Arctic_0.1x0.1" #PolarRES run, this is not needed, as the same is if the above 1x1 is used, it is just a different name of the files
GRIDFILE=/cluster/home/irismuz/CTSM_EXICE/tools/contrib/wrf2clm_land.nc #should be set, a SCRIPgrid file
phys="clm4_5"

MKMAPDATA_OPTIONS="-v -i"

#----------------------------------------------------------------------
# Set parameters
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# Begin main script
#----------------------------------------------------------------------

if [ -z "$RES" ]; then
echo "Run for all valid resolutions"
resols=`../../bld/queryDefaultNamelist.pl -res list -silent`
if [ ! -z "$GRIDFILE" ]; then
    echo "When GRIDFILE set RES also needs to be set for a single resolution"
    exit 1
fi
else
resols="$RES"
fi
if [ -z "$GRIDFILE" ]; then
grid=""
else
if [[ ${#resols[@]} > 1 ]]; then
    echo "When GRIDFILE is specificed only one resolution can also be given (# resolutions ${#resols[@]})"
    echo "Resolutions input is: $resols"
    exit 1
fi
grid="-f $GRIDFILE"
fi

if [[ -z "$MKMAPDATA_OPTIONS" ]]; then
echo "Run with standard options"
options=" "
else
options="$MKMAPDATA_OPTIONS"
fi
echo "Create mapping files for this list of resolutions: $resols"

#----------------------------------------------------------------------

for res in $resols; do
echo "Create mapping files for: $res"
#----------------------------------------------------------------------
cmdargs="-r $res $grid $options"

# For single-point and regional resolutions, tell mkmapdata that
# output type is regional
if [[ `echo "$res" | grep -c "1x1"` -gt 0 || `echo "$res" | grep -c "5x5_"` -gt 0 ]]; then
    res_type="regional"
else
    res_type="global"
fi
# Assume if you are providing a gridfile that the grid is regional
if [[ $grid != "" ]]; then
    res_type="regional"
fi

cmdargs="$cmdargs -t $res_type"

echo "$res_type"
if [ "$res_type" = "regional" ]; then
    echo "regional"
    # For regional and (especially) single-point grids, we can get
    # errors when trying to use multiple processors - so just use 1.
    # We also do NOT set batch mode in this case, because some
    # machines (e.g., yellowstone) do not listen to REGRID_PROC, so to
    # get a single processor, we need to run mkmapdata.sh in
    # interactive mode.
    regrid_num_proc=1
else
    echo "global"
    regrid_num_proc=8
    if [ ! -z "$LSFUSER" ]; then
        echo "batch"
    cmdargs="$cmdargs -b"
    fi
    if [ ! -z "$PBS_O_WORKDIR" ]; then
        cd $PBS_O_WORKDIR
    cmdargs="$cmdargs -b"
    fi
fi

REGRID_PROC=1

echo "args: $cmdargs"
echo "time env REGRID_PROC=$regrid_num_proc ./mkmapdata.sh $cmdargs\n"
time env REGRID_PROC=$regrid_num_proc ./mkmapdata.sh $cmdargs
done
