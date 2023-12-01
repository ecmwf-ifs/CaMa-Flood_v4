#!/bin/sh

#### initial setting ========================================
## project name
TAG=tmpdat
OUT_DAMPARAM="../dam_param.csv"

## minimum drainage area [km2] to exclude small reservoirs
MINUPAREA=0
#MINUPAREA=1000

## Naturalized simulation (natsim) parameters
#Sample test1: test1-glb_15min (this is just for testing. better to use >30 year data)
SYEAR=2000   ## Start year of natsim
EYEAR=2001   ## End   year of natsim
DT=86400     ## time step of outflw.bin data (sec)

#Sample test4: test4-e2o_ecmwf-glb_15min
#SYEAR=1980   ## Start year of natsim
#EYEAR=2014   ## End   year of natsim
#DT=86400     ## time step of outflw.bin data (sec)

#===========================================================
mkdir -p ./${TAG}

##==========================
# estimate paramters from naturalized simulation and reservoir datasets

##### (1) calculate mean and annual max discharge from naturalized simulations
echo "(1)----------"
echo "@@@ ./script/get_annualmax_mean.py $SYEAR $EYEAR $DT $TAG"
echo "output (binary): tmp_p01_AnnualMax.bin, tmp_p01_AnnualMean.bin"
python ./script/get_annualmax_mean.py $SYEAR $EYEAR $DT $TAG

###
##### (2) calculate 100year discharge from annual max discharge
echo "(2)----------"
echo "@@@ ./script/get_100yrDischarge.py $SYEAR $EYEAR $TAG"
echo "output (binary): tmp_p02_100year.bin"
python ./script/get_100yrDischarge.py $SYEAR $EYEAR $TAG
###
##### (3) estimate dam storage parameter, using GRSAD and ReGeom data
echo "(3)----------"
echo "@@@ ./script/est_fldsto_surfacearea.py"
echo "output (csv): tmp_p03_fldsto.csv"
python ./script/est_fldsto_surfacearea.py $TAG

## (4) merge dam location and parameter files"
echo "(4)----------"
echo "@@@ ./script/complete_damcsv.py"
echo "output (csv): dam_params_comp.csv"
python ./script/complete_damcsv.py $TAG $MINUPAREA


##-----
## (5) Finalize parameter file"

ND=`cat $TAG/dam_params_comp.csv | wc -l`
NDAMS=$(( $ND - 1 ))
echo "(5)----------"
echo "NDAMS allocated: $NDAMS"

echo "@@@ create dam param file:  $OUT_DAMPARAM"
echo "${NDAMS},NDAMS"           >  $OUT_DAMPARAM
cat ./$TAG/dam_params_comp.csv  >> $OUT_DAMPARAM


echo ""
echo "###### NOTE ######"
echo "@@@ If needed, please manually edit the dam parameter file: " $OUT_DAMPARAM

exit 0
