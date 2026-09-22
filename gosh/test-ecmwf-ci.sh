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

#*** defaults, overridable on the command line
BASE=$(pwd)/..                              # CaMa-Flood base directory
DATA_REPO="https://sites.ecmwf.int/repository/ecland/camaflood"   # input data repository
CDO_FMT="%20.8f"                            # cdo outputf precision format
EXE_PREFIX="time"                           # command prepended to the model executable
RUN_DIR="./glb_15min_test"                  # directory to run the simulation
NCPUS=16                                    # number of OpenMP threads

usage() {
    cat << EOU
Usage: $(basename $0) [options]

Run a short, low-resolution CaMa-Flood simulation and compare output norms
against known good values.

Options:
  -b, --base DIR        CaMa-Flood base directory (default: ${BASE})
  -r, --run-dir DIR     directory to run the simulation (default: ${RUN_DIR})
  -d, --data-repo DIR   input data repository (default: ${DATA_REPO})
  -p, --precision FMT   cdo outputf format used for the norms (default: ${CDO_FMT})
  -x, --exe-prefix CMD  command prepended to ./MAIN_cmf, e.g. an MPI launcher
                        (default: "${EXE_PREFIX}", use "" for none)
  -n, --ncpus N         number of OpenMP threads (default: ${NCPUS})
  -h, --help            show this help and exit
EOU
}

while [ $# -gt 0 ]; do
    case "$1" in
        -b|--base)       BASE="$2"; shift 2 ;;
        -r|--run-dir)    RUN_DIR="$2"; shift 2 ;;
        -d|--data-repo)  DATA_REPO="$2"; shift 2 ;;
        -p|--precision)  CDO_FMT="$2"; shift 2 ;;
        -x|--exe-prefix) EXE_PREFIX="$2"; shift 2 ;;
        -n|--ncpus)      NCPUS="$2"; shift 2 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Error: unknown argument '$1'" >&2; usage >&2; exit 1 ;;
    esac
done

set -xe

#*** 0a. Set CaMa-Flood source directory (BASE set above / via command line)
SRC=${BASE}/src

echo $BASE

module load prgenv/intel
module load netcdf4/4.7.4

#*** 0c. OpenMP thread number (NCPUS set above / via command line)
export OMP_NUM_THREADS=${NCPUS}                    # OpenMP cpu num

#================================================
# (1) Experiment setting

#============================
#*** 1a. Experiment directory setting
EXE="MAIN_cmf"                              # Execute file name
PROG=${SRC}/${EXE}                     # location of Fortran main program
NMLIST="./input_cmf.nam"                    # standard namelist
LOGOUT="./log_CaMa.txt"                     # standard log output

#================================================
# (2) Setup

#*** 2a. create running dir 
rm -rf ${RUN_DIR}
mkdir -p ${RUN_DIR}/input ${RUN_DIR}/output
cd ${RUN_DIR}

#*** 2b. for new simulation, remove old files in running directory

#*** pull input files from data repository (DATA_REPO set above / via command line)
curl -o glb_15min.tar.gz ${DATA_REPO}/glb_15min.tar.gz
tar -xzf glb_15min.tar.gz
mv glb_15min/* input/

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
EDAY    = 5                     !  day 
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
echo "Running ${EXE} in ${RUN_DIR}"
${EXE_PREFIX} ./${EXE}

#================================================
# (5) Post-processing norms and check against known good values
module load cdo
rm -f cmf_norms
echo file  mean  min  max > cmf_norms
for f  in output/*.nc; do
    printf "%s " $f >> cmf_norms
    for st in mean min max; do
        stval=$(cdo -s outputf,${CDO_FMT} -fld${st} -tim${st} ${f})
        printf "%s " "$stval" >> cmf_norms
    done
    echo >> cmf_norms
done

diff $BASE/gosh/cmf_norms_known_good cmf_norms || \
    { echo "Error: Output norms differ from known good values"; exit 1; }

exit 0
