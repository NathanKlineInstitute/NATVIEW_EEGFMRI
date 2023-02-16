#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO DO SEGMENTATION OF ANTOMICAL SCAN (FREESURFER)
## Revised from Xi-Nian Zuo https://github.com/zuoxinian/CCS
## Ting Xu, BIDS format input
##########################################################################################################################

## anat_dir
anat_dir=$1
## FS SUBJECTS_DIR
SUBJECTS_DIR=$2 # 
## subject
subject=$3
## brain mask name: fs, tight, loose, edit
mask_name=$4
## if use GPU
use_gpu=$5
## if_rerun
if_rerun=$6

## directory setup
anat_seg_dir=${anat_dir}/segment

# directory example
# anat_dir=${dir}/${subject}/${session_name}/anat # BIDS format
# SUBJECTS_DIR=${dir}/${subject}/${session_name} #FREESURFER SETUP

if [ $# -lt 3 ];
then
        echo -e "\033[47;35m Usage: $0 anat_dir SUBJECTS_DIR subject mask_name(fs-bet, loose, tight, edit) use_gpu if_refun\033[0m"
        exit
fi

if [ -z ${mask_name} ]; then mask_name=fs-bet; fi
if [ -z ${use_gpu} ]; then use_gpu=false; fi
if [ -z ${if_rerun} ]; then if_rerun=false; fi

echo ------------------------------------------
echo !!!! RUNNING ANATOMICAL SEGMENTATION !!!!
echo ------------------------------------------


## 1. Make segment dir
mkdir -p ${anat_seg_dir}

## 2. Change to anat dir
cwd=$( pwd ) ; cd ${anat_dir}/mask

if [ ! -f ${anat_seg_dir}/T1.nii.gz ]; then
  mri_convert -it mgz ${SUBJECTS_DIR}/${subject}/mri/T1.mgz -ot nii ${anat_seg_dir}/T1.nii.gz
fi

# select brainmask
echo ">> select brain mask ${mask_name}"
if [[ ! -e ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz ]]; then 

  rm mask.nii.gz
  if [ ! -f ${SUBJECTS_DIR}/${subject}/mri/brainmask.fsinit.mgz]; then
    cp ${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz ${SUBJECTS_DIR}/${subject}/mri/brainmask.fsinit.mgz
  fi

  if [[ ${mask_name} == "fs-bet" ]]; then
    brainmask=${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz
    ln -s brain_fs_mask.nii.gz mask.nii.gz
  elif [[ ${mask_name} == "tight" ]]; then
    cp ${SUBJECTS_DIR}/${subject}/mri/brainmask.loose.mgz ${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz
    ln -s brain_mask_loose.nii.gz mask.nii.gz
  elif [[ ${mask_name} == "loose" ]]; then
    cp ${SUBJECTS_DIR}/${subject}/mri/brainmask.tight.mgz ${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz
    ln -s brain_mask_tight.nii.gz mask.nii.gz
  elif [[ ${mask_name} == "edit" ]]; then
    if [ -f ${anat_dir}/mask/mask.edit.nii.gz ]; then
      ln -s mask.edit.nii.gz mask.nii.gz
      cp ${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz ${SUBJECTS_DIR}/${subject}/mri/brainmask.fsinit.mgz
      3dresample -inset ${anat_dir}/mask/mask.edit.nii.gz -master ${anat_seg_dir}/T1.nii.gz -prefix ${SUBJECTS_DIR}/${subject}/mri/mask.nii.gz
      mri_convert ${SUBJECTS_DIR}/${subject}/mri/mask.nii.gz ${SUBJECTS_DIR}/${subject}/mri/mask.mgz
      mri_mask ${SUBJECTS_DIR}/${subject}/mri/T1.mgz ${SUBJECTS_DIR}/${subject}/mri/mask.mgz ${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz
      rm ${SUBJECTS_DIR}/${subject}/mri/mask.mgz ${SUBJECTS_DIR}/${subject}/mri/mask.nii.gz
    else
      echo "!!! ERROR: edited mask path and name must be anat_dir/mask/mask.edit.nii.gz"
      exit
    fi
  else
    echo "!!! Select correct brain mask (fs-bet, tight, loose, edit)"
  fi

fi

cd ${cmd}
  
cd ${anat_seg_dir}
## 3. Segment the brain (Freeserfer segmentation)
if [ ! -f ${anat_seg_dir}/brainmask.nii.gz ]; then
  mri_convert -it mgz ${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz -ot nii ${anat_seg_dir}/brainmask.nii.gz
fi
if [[ ! -e ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz ]]; then
  echo "Segmenting brain for ${subject} (May take more than 24 hours ...)"
  if [ "${use_gpu}" = "true" ]; then
    recon-all -s ${subject} -autorecon2 -autorecon3 -use-gpu -no-isrunning
  else
    recon-all -s ${subject} -autorecon2 -autorecon3 -no-isrunning
  fi
fi

## freesurfer version
if [ ! -f segment_wm_erode1.nii.gz ] || [ ! -f segment_csf_erode1.nii.gz ]; then
echo "RUN >> Convert FS aseg to create csf/wm segment files"
  mri_convert -it mgz ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz -ot nii aseg.nii.gz
  mri_binarize --i ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz --o segment_wm.nii.gz --match 2 41 7 46 251 252 253 254 255 
  mri_binarize --i ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz --o segment_csf.nii.gz --match 4 5 43 44 31 63 
  mri_binarize --i ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz --o segment_wm_erode1.nii.gz --match 2 41 7 46 251 252 253 254 255 --erode 1
  mri_binarize --i ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz --o segment_csf_erode1.nii.gz --match 4 5 43 44 31 63 --erode 1
  # Create for flirt -bbr to match with FAST wm output to include Thalamus, Thalamus-Proper*, VentralDC, Stem
  mri_binarize --i ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz --o segment_wm+sub+stem.nii.gz --match 2 41 7 46 251 252 253 254 255 9 48 10 49 28 60 16
else
  echo "SKIP >> Convert FS aseg to create csf/wm segment files"
fi

## FAST segmentation: CSF: *_pve_0, GM: *_pve_1, WM: *_pve_2
echo "-------------------------------------------"
echo "FAST segmentation"
echo "-------------------------------------------"
mkdir ${anat_dir}/segment_fast
cd ${anat_dir}/segment_fast
if [[ ! -e segment_pveseg.nii.gz ]]; then
  fast -o segment ${anat_seg_dir}/T1.nii.gz
else
  echo "SKIP >> FAST segmentation done"
fi
if [ ! -f segment_wm_erode1.nii.gz ] || [ ! -f segment_csf_erode1.nii.gz ]; then
  echo "RUN >> Convert FS aseg to create csf/wm segment files"
  fslmaths segment_pve_1.nii.gz -thr 0.99 segment_csf.nii.gz
  fslmaths segment_pve_2.nii.gz -thr 0.99 segment_wm.nii.gz
  mri_binarize --i segment_csf.nii.gz --o segment_csf_erode1.nii.gz --match 1 --erode 1
  mri_binarize --i segment_wm.nii.gz --o segment_wm_erode1.nii.gz --match 1 --erode 1
else
  echo "SKIP >> Convert FS aseg to create csf/wm segment files"
fi

cd ${cwd}
