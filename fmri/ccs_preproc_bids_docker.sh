#!/usr/bin/env bash
##########################################################################################################################
## docker image: https://hub.docker.com/r/tingsterx/ccs-bids
## export PATH for docker
. /neurodocker/startup.sh
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4
##########################################################################################################################
################### Setup code and data directory 
## ccs template directory
ccs_dir=/opt/ccs
## directory where scripts are located
scripts_dir=/opt/ccs/preprocessing
## full/path/to/site
analysisdirectory=/data
################### Setup data 
# subject ID: e.g. sub-001
subject=$1
# session ID: e.g. ses-001
session_name=$2
# run ID: e.g. run-001
run_name=$3
# which brain mask to use
brainmask_name=fs-bet # options for fs-bet, tight, loose, edit
# if run anatomical pipeline
run_anat=true
# if run functional pipeline
run_func=true
##########################################################################################################################
################### Anat parameters
## anat_dir_name
anat_dir_name=anat
## name of anatomical scan (no extension)
anat_name=T1w
## if do anat registration
do_anat_reg=true 
## if do anat segmentation
do_anat_seg=true
## if use freesurfer derived volumes
fs_brain=true
## if use svd to extract the mean ts
svd=false
## if denoise the T1 input
do_denoise=true
## if using gcut for skullstripping in FS
use_gcut=true
## how many anat scans
num_scans=1
## use gpu
use_gpu=false
## anatomical registration directory name
anat_reg_dir_name=reg
#################### Func parameters
## name of resting-state scan (no extension)
func_name=func
## func_minimal directory name
func_min_dir_name=func_minimal
## func reg directory name
func_reg_dir_name=func_reg
## func segmentation directory name
func_seg_dir_name=func_seg
## func nuisance dir name
nuisance_dir_name=func_nuisance
## func nuisance_reg and final
func_proc_dir_name=func_preproc
## func surface dir name (freesurfer version) - not used yet
func_surfFS_dir_name=func_surf_fs
## func surface dir name (workbench version) - not used yet
func_surfWB_dir_name=func_surf_wb
## number of volume dropping
numDropping=0
## func to anat reg method: fsbbr flirtbbr flirt
reg_method=fsbbr
## resolution of func data (3mm)
res_func=3
## if use bias corrected example_func
if_use_bc_func=true
## use svd (to average signal in csf and wm)
svd=false
## motion model (default 24, options: 6,12,24)
motion_model=24
## if use compcor (instead of csf+wm)
compcor=false
## highpass-lowpass filtering
hp=0.01
lp=0.1
## smooth kernel FWHM
FWHM=6
## write out resolution of preprocessed data (in anat space)
res_anat=3
## write out resolution of preprocessed data in standard (mni152) space
res_std=3
## cleanup the existing preprocessed data
if_rerun=false
##########################################################################################################################
## standard brain
standard_head=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz
standard_brain=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz
standard_template=${ccs_dir}/templates/MNI152_T1_3mm_brain.nii.gz
fsaverage=fsaverage5
##########################################################################################################################

## BIDS format directory setup
anat_dir=${analysisdirectory}/${subject}/${session_name}/${anat_dir_name}
SUBJECTS_DIR=${analysisdirectory}/${subject}/${session_name}
func_dir=${analysisdirectory}/${subject}/${session_name}/${run_name}
TR_file=${func_dir}/TR.txt
tpattern_file=${func_dir}/SliceTiming.txt

echo "-----------------------------------------------------"
echo "Preprocessing of data: ${subject} ${session_name} ${run_name}..."
echo "-----------------------------------------------------"
##########################################################################################################################
## Anatomical Image Preprocessing
##########################################################################################################################

if [ ${run_anat} == true ]; then

  ## 1. skullstriping 
  ${scripts_dir}/ccs_bids_01_anatpreproc.sh ${anat_dir} ${SUBJECTS_DIR} ${subject} ${anat_name} ${do_denoise} ${num_scans} ${use_gcut} ${scripts_dir}
  
  ## 2. freesurfer pipeline
  ${scripts_dir}/ccs_bids_01_anatsurfrecon.sh ${anat_dir} ${SUBJECTS_DIR} ${subject} ${brainmask_name} ${mask_name} ${use_gpu}
  
  ## 3. registration
  ${scripts_dir}/ccs_bids_02_anatregister.sh ${ccs_dir} ${anat_dir} ${SUBJECTS_DIR} ${subject} ${anat_reg_dir_name}

fi

##########################################################################################################################
## Functional Image Preprocessing
##########################################################################################################################

if [ ${run_func} == true ]; then

  ## 1. Preprocessing functional images
  ${scripts_dir}/ccs_bids_01_funcpreproc.sh ${func_name} ${anat_dir} ${func_dir} ${numDropping} ${TR_file} ${tpattern_file} ${func_min_dir_name} ${if_rerun} ${clean_up}
  
  ## 2. func to anat registration
  ${scripts_dir}/ccs_bids_02_funcregister_func2anat.sh ${anat_dir} ${anat_reg_dir_name} ${SUBJECTS_DIR} ${subject} ${func_name} ${func_dir} ${func_min_dir_name} ${reg_method} ${func_reg_dir_name} ${if_use_bc_func} ${res_func} ${if_rerun}
  
  ## 2. func to std registration
  ${scripts_dir}/ccs_bids_02_funcregister_func2std.sh ${ccs_dir} ${anat_dir} ${anat_reg_dir_name} ${func_name} ${func_dir} ${func_min_dir_name} ${func_reg_dir_name} ${res_func} ${if_rerun}
  
  ## 3. func segmentation
  ${scripts_dir}/ccs_bids_03_funcsegment.sh ${anat_dir} ${SUBJECTS_DIR} ${subject} ${func_name} ${func_dir} ${func_reg_dir_name} ${func_seg_dir_name} ${if_rerun}
  
  ## 4. func generate nuisance 
  ${scripts_dir}/ccs_bids_04_funcnuisance.sh ${func_name} ${func_dir} ${func_min_dir_name} ${func_reg_dir_name} ${func_seg_dir_name} ${nuisance_dir_name} ${svd} ${if_rerun}
  
  ## 5. func nuisance regression, filter, smoothing preproc
  ${scripts_dir}/ccs_bids_05_funcpreproc_vol.sh ${anat_dir} ${anat_reg_dir_name} ${func_name} ${func_dir} ${func_min_dir_name} ${func_reg_dir_name} ${nuisance_dir_name} ${func_proc_dir_name} ${motion_model} ${compcor} ${hp} ${lp} ${FWHM} ${res_anat} ${res_std} ${ccs_dir} ${if_rerun}

fi
