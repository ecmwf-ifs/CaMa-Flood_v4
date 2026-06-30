#!/bin/bash
#==========================================================
# CaMa-Flood test script to run a short, low-resolution simulation for continuous integration test.
#
# (C) M. Wortmann, 2026 (based on test1-glb_15min.sh)
#
# Licensed under the Apache License, Version 2.0 (the "License");
#   You may not use this file except in compliance with the License.
#   You may obtain a copy of the License at: http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is 
#  distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and limitations under the License.
#==========================================================
set -xe

#*** 0a. Set CaMa-Flood base directory
BASE=`pwd`/..
SRC=${BASE}/src

echo $BASE

module load prgenv/intel
module load netcdf4/4.7.4

#*** 0c. OpenMP thread number
export OMP_NUM_THREADS=16                    # OpenMP cpu num

#================================================
# (1) Experiment setting
# -- some non-default options can be modified in NAMELIST section 

#============================
#*** 1a. Experiment directory setting
EXP="test-ecmwf-ci"                       # experiment name (output directory name)
RDIR=${BASE}/out/${EXP}                     # directory to run CaMa-Flood
EXE="MAIN_cmf"                              # Execute file name
PROG=${SRC}/${EXE}                     # location of Fortran main program
NMLIST="./input_cmf.nam"                    # standard namelist
LOGOUT="./log_CaMa.txt"                     # standard log output

#================================================
# (2) Setup

#*** 2a. create running dir 
rm -rf ${RDIR}
mkdir -p ${RDIR}/input ${RDIR}/output
cd ${RDIR}

#*** 2b. for new simulation, remove old files in running directory

#*** pull input files from data repository
DATA_REPO="/perm/dimw/cmf_debugging/cmf_tests/cmf_v420_pkg"
for f in nextxy.bin ctmare.bin elevtn.bin nxtdst.bin rivlen.bin fldhgt.bin rivwth_gwdlr.bin rivhgt.bin rivman.bin bifprm.txt inpmat_test-1deg.bin diminfo_test-1deg.txt; do
    cp ${DATA_REPO}/map/glb_15min/$f ${RDIR}/input
done
cp ${DATA_REPO}/inp/test_1deg/runoff/Roff____2001010[123].one ${RDIR}/input

#*** namelist settings
rm -f ${NMLIST}
cat >> ${NMLIST} << EOF
&NRUNVER
LADPSTP=.true.
LPTHOUT=.true.
LRESTART=.false.
LDAMOUT=.false.
/
&NDIMTIME
CDIMINFO = "./input/diminfo_test-1deg.txt"               ! text file for dimention information
DT       = 86400                       ! time step length (sec)
IFRQ_INP = 24                 ! input forcing update frequency (hour)
/
&NPARAM
PMANRIV  = 0.03D0                  ! manning coefficient river
PMANFLD  = 0.10D0                  ! manning coefficient floodplain
PDSTMTH  = 10000.D0                ! downstream distance at river mouth [m]
PCADP    = 0.7                     ! CFL coefficient
/
&NSIMTIME
SYEAR   = 2001                     ! start year
SMON    = 1                      !  month 
SDAY    = 1                      !  day 
SHOUR   = 0                     !  houe
EYEAR   = 2001                     ! end year
EMON    = 1                      !  month 
EDAY    = 4                     !  day 
EHOUR   = 0                     !  hour
/
&NMAP
LMAPCDF    = .FALSE.                ! * true for netCDF map input
CNEXTXY    = "./input/nextxy.bin"              ! river network nextxy
CGRAREA    = "./input/ctmare.bin"              ! catchment area
CELEVTN    = "./input/elevtn.bin"              ! bank top elevation
CNXTDST    = "./input/nxtdst.bin"              ! distance to next outlet
CRIVLEN    = "./input/rivlen.bin"              ! river channel length
CFLDHGT    = "./input/fldhgt.bin"              ! floodplain elevation profile
CRIVWTH    = "./input/rivwth_gwdlr.bin"              ! channel width
CRIVHGT    = "./input/rivhgt.bin"              ! channel depth
CRIVMAN    = "./input/rivman.bin"              ! river manning coefficient
CPTHOUT    = "./input/bifprm.txt"              ! bifurcation channel table
/
&NRESTART
CRESTSTO = "restart2001010100.bin"               ! restart file
CRESTDIR = "./"               ! restart directory
CVNREST  = "restart"                ! restart variable name
LRESTCDF = .FALSE.                 ! * true for netCDF restart file (double precision)
IFRQ_RST = 0                 ! restart write frequency (1-24: hour, 0:end of run)
/
&NFORCE
LINPCDF  = .FALSE.                  ! true for netCDF runoff
LINTERP  = .TRUE.                  ! true for runoff interpolation using input matrix
CINPMAT  = "./input/inpmat_test-1deg.bin"                ! input matrix file name
DROFUNIT = 86400000                 ! runoff unit conversion
CROFDIR  = "./input"                ! runoff             input directory
CROFPRE  = "Roff____"                ! runoff             input prefix
CROFSUF  = ".one"                ! runoff             input suffix
/
&NOUTPUT
COUTDIR  = "./output/"                ! OUTPUT DIRECTORY
CVARSOUT = "totout,rivout,rivsto,rivdph,rivvel,fldout,fldsto,flddph,fldfrc,fldare,sfcelv,outflw,storge,pthflw,pthout,maxsto,maxflw,maxdph"               ! Comma-separated list of output variables to save 
COUTTAG  = ""                ! Output Tag Name for each experiment
LOUTVEC  = .FALSE.                      ! TRUE FOR VECTORIAL OUTPUT, FALSE FOR NX,NY OUTPUT
LOUTCDF  = .TRUE.                  ! * true for netcdf outptu false for binary
NDLEVEL  = 0                           ! * NETCDF DEFLATION LEVEL 
IFRQ_OUT = 24                 ! output data write frequency (hour)
/
&NDAMOUT
/
EOF

#================================================
# (3) Build
options=(
    "CFLAGS=-DUseCDF_CMF -DSinglePrec_CMF"
    "INC=$(nc-config --fflags)"
    "LIB=$(nc-config --flibs)"
    "FCMP=ifort -qopenmp"
    "FFLAGS=-O3 -warn all -fpp -free -assume byterecl -heap-arrays -nogen-interface -lpthread -static-intel -align array64byte"
)

make -C "${SRC}" clean
make -C "${SRC}" "${options[@]}" all
ln -s ${PROG} ./${EXE}

#================================================
# (4) Run model
echo "Running ${EXE} in ${RDIR}"
time ./${EXE}

#================================================
# (5) Post-processing norms
module load cdo
rm -f cmf_norms
for f  in output/*.nc; do
    echo $f mean values: >> cmf_norms
    cdo -s infon $f >> cmf_norms
done

exit 0
