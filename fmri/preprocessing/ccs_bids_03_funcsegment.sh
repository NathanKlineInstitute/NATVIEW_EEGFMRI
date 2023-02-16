#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO DO SEGMENTATION OF FUNCTIONAL SCAN
## Xi-Nian Zuo, Aug. 13, 2011; Revised at IPCAS, Feb. 12, 2013.
## Ting Xu, 202204, BIDS format input
##########################################################################################################################

## anat_dir
anat_dir=$1
## SUBJECTS_DIR
SUBJECTS_DIR=$2
## subject
subject=$3
## filename of resting-state scan (no extension)
rest=$4
## func_dir
func_dir=$5
## name of func reg directory
func_reg_dir_name=$6
## name of func seg directory
func_seg_dir_name=$7
## if rerun
if_redo=$8

## directory setup
func_reg_dir=${func_dir}/${func_reg_dir_name}
func_seg_dir=${func_dir}/${func_seg_dir_name}

if [ $# -lt 5 ];
then
        echo -e "\033[47;35m Usage: $0 anat_dir SUBJECTS_DIR subject func_name func_dir func_reg_dir_name func_seg_dir_name if_redo \033[0m"
        exit
fi

echo -----------------------------------------
echo !!!! RUNNING FUNCTIONAL SEGMENTATION !!!!
echo -----------------------------------------

if [ -f ${anat_dir}/segment/segment_csf_erode1.nii.gz ] && [ -f ${anat_dir}/segment/segment_wm_erode1.nii.gz ]; then
  anat_seg_dir=${anat_dir}/segment
  echo "use freesurfer segment (erode1) "
elif [ -f ${anat_dir}/segment_fast/segment_csf_erode1.nii.gz ] && [ -f ${anat_dir}/segment_fast/segment_wm_erode1.nii.gz ];then
  anat_seg_dir=${anat_dir}/segment_fast
  echo "use FSL FAST segment (erode1) "
else
  echo "!!! No wm/csf segment of anatomical images. Please check anatsurface preprocess"
  exit
fi

if [ ! -e ${func_reg_dir}/bbregister.dof6.dat ]; then
  echo "!!! No func-anat registration file. Please check func2anat preprocess"
  exit
fi

if [ -z ${if_redo} ]; then
  if_redo=false
fi

##----------------------------------------
## define vcheck funcion
vcheck (){
    underlay=$1
    overlay=$2
    figout=$3
    workdir=`dirname ${figout}`
    pushd ${workdir}
    bg_min=`fslstats ${underlay} -P 1`
    bg_max=`fslstats ${underlay} -P 99`
    overlay 1 1 ${underlay} ${bg_min} ${bg_max} ${overlay} 1 1 rendered_mask
    slicer rendered_mask -s 2 \
      -z 0.30 sl1.png -z 0.40 sl2.png -z 0.45 sl3.png -z 0.50 sl4.png -z 0.55 sl5.png \
      -z 0.60 sl6.png -z 0.70 sl7.png -z 0.80 sl8.png -z 0.90 sl9.png 
    pngappend sl1.png + sl2.png + sl3.png + sl4.png + sl5.png + sl6.png + sl7.png + sl8.png + sl9.png ${figout} 
    rm -f rendered_mask.nii.gz sl?.png
    popd
}
## -----------------------------------------

## 1. Make segment dir
mkdir -p ${func_seg_dir}

cwd=$( pwd )
## 2. Change to func dir
cd ${func_seg_dir}

## 3. Global (brainmask): refined mask from registration step
if [ ! -e ${func_seg_dir}/global_mask.nii.gz ]; then 
  3dcopy ${func_reg_dir}/${rest}_pp_mask.nii.gz ${func_seg_dir}/global_mask.nii.gz
  vcheck ${func_reg_dir}/example_func.nii.gz ${func_seg_dir}/global_mask.nii.gz ${func_seg_dir}/global_mask.png
fi

## CSF
## 4. Register csf to native space
#FS
if [ ${if_redo} == "true" ] || [[ ! -f ${func_seg_dir}/csf_mask.nii.gz ]]; then
  echo ">> Registering ${subject} csf to native func space"
  mri_label2vol --seg ${anat_seg_dir}/segment_csf_erode1.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --temp ${func_reg_dir}/example_func.nii.gz --fillthresh 0.1 --o ${func_seg_dir}/csf2func.nii.gz --pvf ${func_seg_dir}/csf2func_pvf.nii.gz
  fslmaths ${func_seg_dir}/csf2func.nii.gz -mas ${func_seg_dir}/global_mask.nii.gz -bin ${func_seg_dir}/csf_mask.nii.gz
  vcheck ${func_reg_dir}/example_func.nii.gz ${func_seg_dir}/csf_mask.nii.gz ${func_seg_dir}/csf_mask.png
else
  echo ">> Registering ${subject} csf to native func space (done, skip)"
fi

## WM
## 5. Register wm to native space
#FS
if [ ${if_redo} == "true" ] || [[ ! -f ${func_seg_dir}/wm_mask.nii.gz ]]; then
  echo ">> Registering ${subject} wm to native func space"
  mri_label2vol --seg ${anat_seg_dir}/segment_wm_erode1.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --temp ${func_reg_dir}/example_func.nii.gz --fillthresh 0.95 --o ${func_seg_dir}/wm2func.nii.gz --pvf ${func_seg_dir}/wm2func_pvf.nii.gz
  fslmaths ${func_seg_dir}/wm2func.nii.gz -mas ${func_seg_dir}/global_mask.nii.gz -bin ${func_seg_dir}/wm_mask.nii.gz
  vcheck ${func_reg_dir}/example_func.nii.gz ${func_seg_dir}/wm_mask.nii.gz ${func_seg_dir}/wm_mask.png
else
  echo ">> Registering ${subject} wm to native func space (done, skip)"
fi

##---------------------------------------------
## FS aseg 
if [ -e ${SUBJECTS_DIR}/${subject}/mri/aparc.a2009s+aseg.mgz ]; then
  if [ ${if_redo} == "true" ] || [[ ! -f ${func_seg_dir}/aseg2func.nii.gz ]]; then
  echo ">> Register FS aseg to the func space"
  mri_vol2vol --mov ${func_reg_dir}/example_func.nii.gz --targ ${SUBJECTS_DIR}/${subject}/mri/aparc.a2009s+aseg.mgz --inv --interp nearest --o ${func_seg_dir}/aparc.a2009s+aseg2func.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --no-save-reg
  mri_vol2vol --mov ${func_reg_dir}/example_func.nii.gz --targ ${SUBJECTS_DIR}/${subject}/mri/aparc+aseg.mgz --inv --interp nearest --o ${func_seg_dir}/aparc+aseg2func.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --no-save-reg
  mri_vol2vol --mov ${func_reg_dir}/example_func.nii.gz --targ ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz --inv --interp nearest --o ${func_seg_dir}/aseg2func.nii.gz --reg ${func_reg_dir}/bbregister.dof6.dat --no-save-reg
  fi
else
  echo -e \\"e[0;41m !!!Check!!! \\e[0m"
  echo "!!!FS aparc.a2009s+aseg is not existing. Check FS recon-all step"
fi

cd ${cwd}
