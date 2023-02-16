#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO PREPROCESS THE FUNCTIONAL SCAN (INTEGRATE AFNI AND FSL)
## Xi-Nian Zuo (zuoxinian@gmail.com). Aug. 13, 2011; Revised at IPCAS, Feb. 12, 2013.
## Ting Xu 202204, BIDS format input
## Note: anat_dir/reg/highres.nii.gz
##########################################################################################################################

## name of the resting-state scan
rest=$1
## name of the anat directory
anat_dir=$2
## name of the func directory
func_dir=$3
## number of volumes dropped
ndvols=$4
## TR
TR_file=$5
## Tpattern: see helps from AFNI command 3dTshift, e.g., seq+z or alt+z. or file '@'
tpattern_file=$6
## name of the func_minimal preprocessed directory
func_min_dir_name=$7 # func_minimal
## if re-run
if_redo=$8
## clean-up some medial file
if_cleanup=$9 
## directory_setup
highres_rpi=${anat_dir}/reg/highres_rpi.nii.gz
func_min_dir=${func_dir}/${func_min_dir_name}

if [ $# -lt 5 ]; then
        echo -e "\033[47;35m Usage: $0 func_name, anat_dir, func_dir, number of volumes dropped, TR_file (TR.txt or TR in sec), slice timing file (full path of SliceTiming.txt or seq+z, alt+z2 saved in a file, etc. or none), output_dir_name (default: func_minimal) if_redo if_cleanup \033[0m"
        exit
fi

if [ -z $func_min_dir_name ]; then func_min_dir_name=func_minimal; fi
if [ -z $if_redo ]; then if_redo=false; fi
if [ -z $if_cleanup ]; then if_cleanup=true; fi

cwd=$( pwd )

## Setup the working directory and mkdir
mkdir -p ${func_min_dir}/reg4mask
pushd ${func_min_dir}
if [ -f ${rest}.nii.gz ]; then rm ${rest}.nii.gz; fi
ln -s ../${rest}.nii.gz ${rest}.nii.gz
popd

echo "---------------------------------------"
echo "!!!! PREPROCESSING FUNCTIONAL SCAN !!!!"
echo "---------------------------------------"

## Setup the TR and SliceTiming Pattern
TR=`cat ${TR_file}`
echo "TR is ${TR}"
if [ -z $tpattern_file ]; then
  tpattern="none"
else
  nline=`cat ${tpattern_file} | wc -l`
  if [ $nline -gt 1 ]; then
  tpattern="@${tpattern_file}"
  else
    tpattern=`cat ${tpattern_file}`
  fi
fi

##

cd ${func_min_dir}
## If rerun everything
if [[ ${if_redo} == "true" ]]; then
	echo -----------------------------------------------------------
	echo "!!! Clean up the existing files and RE-RUN funcpreproc step"
	echo -----------------------------------------------------------
	rm -f ${rest}_dr.nii.gz ${rest}_dspk.nii.gz ${rest}_ts.nii.gz ${rest}_ro.nii.gz ${rest}_ro_mean.nii.gz ${rest}_mc.nii.gz ${rest}_mc.1D ${rest}_mask.initD.nii.gz ${rest}_pp_mask.nii.gz example_func.nii.gz example_func_brain.nii.gz example_func_bc.nii.gz example_func_brain_bc.nii.gz
        rm reg4mask
else
	echo -----------------------------------------------------------
	echo "!!! The existing preprocessed files will be used, if any "
	echo -----------------------------------------------------------
fi

if [[ ! -f ${rest}_mc.nii.gz ]]; then

## 0. Dropping first # TRS
if [[ ! -f ${rest}_dr.nii.gz ]]; then
  echo "Dropping first ${ndvols} TRs"
  nvols=`fslnvols ${rest}.nii.gz`
  ## first timepoint (remember timepoint numbering starts from 0)
  TRstart=${ndvols} 
  ## last timepoint
  let "TRend = ${nvols} - 1"
  3dcalc -a ${rest}.nii.gz[${TRstart}..${TRend}] -expr 'a' -prefix ${rest}_dr.nii.gz -datum float
  3drefit -TR ${TR} ${rest}_dr.nii.gz
  echo "This func dataset < 15 time points" > ../func_preproc.log
else
  echo "Dropping first ${ndvols} TRs (done, skip)"
fi

## 1. Despiking (particular helpful for motion)
if [[ ! -f ${rest}_dspk.nii.gz ]]; then
  echo "Despiking timeseries for this func dataset"
  3dDespike -prefix ${rest}_dspk.nii.gz ${rest}_dr.nii.gz
else
  echo "Despiking timeseries for this func dataset (done, skip)"
fi

## 2. Slice timing
if [[ ! -f ${rest}_ts.nii.gz ]] && [[ ${tpattern} != "none" ]]; then
  echo "Slice timing for this func dataset"
  3dTshift -prefix ${rest}_ts.nii.gz -tpattern ${tpattern} -tzero 0 ${rest}_dspk.nii.gz
  echo "Deobliquing this func dataset"
  3drefit -deoblique ${rest}_ts.nii.gz
else
  echo "Slice timing for this func dataset (done, skip)"
fi

##3. Reorient into fsl friendly space (what AFNI calls RPI)
if [[ ! -f ${rest}_ro.nii.gz ]] && [[ ${tpattern} != "none" ]]; then
  echo "Reorienting for this func dataset"
  3dresample -orient RPI -inset ${rest}_ts.nii.gz -prefix ${rest}_ro.nii.gz
elif [[ ! -f ${rest}_ro.nii.gz ]] && [[ ${tpattern} == "none" ]]; then
  3dresample -orient RPI -inset ${rest}_dspk.nii.gz -prefix ${rest}_ro.nii.gz
else
  echo "Reorienting for this func dataset (done, skip)"
fi

##4. Motion correct to average of timeseries
if [[ ! -f ${rest}_mc.nii.gz ]] || [[ ! -f ${rest}_mc.1D ]]; then
  echo "Motion correcting for this func dataset"
  rm -f ${rest}_ro_mean.nii.gz
  3dTstat -mean -prefix ${rest}_ro_mean.nii.gz ${rest}_ro.nii.gz 
  3dvolreg -Fourier -twopass -base ${rest}_ro_mean.nii.gz -zpad 4 -prefix ${rest}_mc.nii.gz -1Dfile ${rest}_mc.1D ${rest}_ro.nii.gz
else
  echo "Motion correcting for this func dataset (done, skip)"
fi

##5 Extract one volume as an example_func (Lucky 8)
if [[ ! -f example_func.nii.gz ]]; then
  echo "Extract one volume (No.8) as an example_func"
  fslroi ${rest}_mc.nii.gz example_func.nii.gz 7 1
else
  echo "Extract one volume (No.8) as an example_func (done, skip)"
fi

##6 Bias Field Correction (used for alignment only)
if [[ ! -f example_func_bc.nii.gz ]]; then
  echo "N4 Bias Field Correction, used for alignment only"
	fslmaths ${rest}_mc.nii.gz -Tmean tmp_func_mc_mean.nii.gz
	N4BiasFieldCorrection -i tmp_func_mc_mean.nii.gz -o tmp_func_bc.nii.gz
	fslmaths tmp_func_mc_mean.nii.gz -sub tmp_func_bc.nii.gz ${rest}_biasfield.nii.gz
	fslmaths example_func.nii.gz -sub ${rest}_biasfield.nii.gz example_func_bc.nii.gz
	rm tmp_func_mc_mean.nii.gz tmp_func_bc.nii.gz
else
  echo "N4 Bias Field Correction, used for alignment only. (done, skip)"
fi

##7 Initial func_pp_mask.init
if [[ ! -f ${rest}_ss.nii.gz ]]; then
  echo "Skull stripping for this func dataset"
  rm ${rest}_mask.initD.nii.gz
  3dAutomask -prefix ${rest}_mask.initD.nii.gz -dilate 1 ${rest}_mc.nii.gz
  if [[ -f example_func_bc.nii.gz ]]; then
    fslmaths example_func_bc.nii.gz -mas ${rest}_mask.initD.nii.gz tmpbrain.nii.gz
  else
    fslmaths example_func.nii.gz -mas ${rest}_mask.initD.nii.gz tmpbrain.nii.gz
  fi
  ## anatomical brain as reference to refine the functional mask
  flirt -ref ${highres_rpi} -in tmpbrain -out reg4mask/example_func2highres_rpi4mask -omat reg4mask/example_func2highres_rpi4mask.mat -cost corratio -dof 6 -interp trilinear 
  ## Create mat file for conversion from subject's anatomical to functional
  convert_xfm -inverse -omat reg4mask/highres_rpi2example_func4mask.mat reg4mask/example_func2highres_rpi4mask.mat
  flirt -ref example_func -in ${highres_rpi} -out tmpT1.nii.gz -applyxfm -init reg4mask/highres_rpi2example_func4mask.mat -interp trilinear
  fslmaths tmpT1.nii.gz -bin -dilM reg4mask/brainmask2example_func.nii.gz ; rm -v tmp*.nii.gz
  fslmaths ${rest}_mc.nii.gz -Tstd -bin ${rest}_pp_mask.init.nii.gz #Rationale: any voxels with detectable signals should be included as in the global mask
  fslmaths ${rest}_pp_mask.init.nii.gz -mul ${rest}_mask.initD.nii.gz -mul reg4mask/brainmask2example_func.nii.gz ${rest}_pp_mask.init.nii.gz -odt char
  fslmaths example_func.nii.gz -mas ${rest}_pp_mask.init.nii.gz example_func_brain.init.nii.gz
  fslmaths example_func_bc.nii.gz -mas ${rest}_pp_mask.init.nii.gz example_func_brain_bc.init.nii.gz
else
  echo "Skull stripping - generate the initial func mask  (done, skip)"
fi

## clean up the 
if [[ ${cleanup} == "true" ]]; then
  echo "clean up: func_dr (dropping), func_dspk (despike), func_ro (reoriented)"
  rm -f ${rest}_dr.nii.gz ${rest}_dspk.nii.gz ${rest}_ro.nii.gz ${rest}_ts.nii.gz
fi

else
  echo "Minimal preprocessing done (skip)"
fi

cd ${cwd}
