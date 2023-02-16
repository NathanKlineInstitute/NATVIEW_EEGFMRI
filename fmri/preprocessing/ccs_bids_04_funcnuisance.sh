#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO DO REGRESS OUT NUISANCE COVARIATES FROM RESTING_STATE SCAN
## Revised from Xi-Nian Zuo https://github.com/zuoxinian/CCS
## Ting Xu, 202204, BIDS format input
##########################################################################################################################

## func filename (no extension)
rest=$1
## func directory
func_dir=$2
## func minimal directory
func_min_dir_name=$3
## func registration directory
func_reg_dir_name=$4
## func segment directory
func_seg_dir_name=$5
## func_preprocessed directory
nuisance_dir_name=$6
## use svd instead of mean
svd=$7
## if rerun
if_rerun=$8


## directory setup
func_min_dir=${func_dir}/${func_min_dir_name}
func_reg_dir=${func_dir}/${func_reg_dir_name}
func_seg_dir=${func_dir}/${func_seg_dir_name}
nuisance_dir=${func_dir}/${nuisance_dir_name}

func_input=${func_reg_dir}/${rest}_gms.nii.gz

if [ $# -lt 7 ];
then
        echo -e "\033[47;35m Usage: $0 func_dataset_name func_dir func_min_dir_namefunc_reg_dir_name func_seg_dir_name nuisance_dir_name svd(false, true) if_rerun \033[0m"
        exit
fi

if [ -z ${svd} ]; then svd=false; fi
if [ -z ${if_rerun} ]; then if_rerun=false; fi

if [ ${svd} == "true" ]; then
  average_method="svd"
else
  average_method="mean"
fi

if [ ! -f ${func_seg_dir}/global_mask.nii.gz ] || [ ! -f ${func_seg_dir}/csf_mask.nii.gz ] || [ ! -f ${func_seg_dir}/wm_mask.nii.gz ]; then
  echo -e \\"e[0;41m !!!Check!!! \\e[0m"
  echo "!!!Check the functional segmentation files"
  exit
fi

if [ ! -f ${func_min_dir}/${rest}_mc.1D ]; then
  echo -e \\"e[0;41m !!!Check!!! \\e[0m"
  echo "!!!Check the motion file generated in the func minimal preprocess step"
  exit
fi

echo --------------------------------------------
echo !!!! RUNNING NUISANCE SIGNAL REGRESSION !!!!
echo --------------------------------------------

cwd=$( pwd )

if [ ${if_rerun} == "true" ]; then
  rm -f ${nuisance_dir}/*
fi

## 1. make nuisance directory
mkdir -p ${nuisance_dir}; cd ${nuisance_dir}


nvols=`fslnvols ${func_input}`
## 2. Prepare regressors
if [ ${nvols} -ne `cat Model_Motion24_CSF_WM_Global.txt | wc -l` ] && [ ${nvols} -ne `cat Model_Motion24_CSF_WM.txt | wc -l` ] ; then
  ## 2.1 generate the temporal derivates of motion
  cp ${func_min_dir}/${rest}_mc.1D ${nuisance_dir}/${rest}_mc.1D
  1d_tool.py -infile ${rest}_mc.1D -derivative -write ${rest}_mcdt.1D
  ## 2.2 Seperate motion parameters into seperate files
  echo "Splitting up ${subject} motion parameters"
  awk '{print $1}' ${rest}_mc.1D > mc1.1D
  awk '{print $2}' ${rest}_mc.1D > mc2.1D
  awk '{print $3}' ${rest}_mc.1D > mc3.1D
  awk '{print $4}' ${rest}_mc.1D > mc4.1D
  awk '{print $5}' ${rest}_mc.1D > mc5.1D
  awk '{print $6}' ${rest}_mc.1D > mc6.1D
  awk '{print $1}' ${rest}_mcdt.1D > mcdt1.1D
  awk '{print $2}' ${rest}_mcdt.1D > mcdt2.1D
  awk '{print $3}' ${rest}_mcdt.1D > mcdt3.1D
  awk '{print $4}' ${rest}_mcdt.1D > mcdt4.1D
  awk '{print $5}' ${rest}_mcdt.1D > mcdt5.1D
  awk '{print $6}' ${rest}_mcdt.1D > mcdt6.1D
  echo "Preparing 1D files for Friston-24 motion correction"
  for ((k=1 ; k <= 6 ; k++)); do
    # calculate the squared MC files
    1deval -a mc${k}.1D -expr 'a*a' > mcsqr${k}.1D
    # calculate the AR and its squared MC files
    1deval -a mc${k}.1D -b mcdt${k}.1D -expr 'a-b' > mcar${k}.1D
    1deval -a mcar${k}.1D -expr 'a*a' > mcarsqr${k}.1D
  done
  # Extract signal for global, csf, and wm
  ## 2.3. Global
  echo "Extracting global signal"
  3dmaskave -mask ${func_seg_dir}/global_mask.nii.gz -quiet ${func_input} > global.1D
  ## 2.4 csf matter
  echo "Extracting signal from csf"
  3dmaskSVD -vnorm -mask ${func_seg_dir}/csf_mask.nii.gz -polort 0 ${func_input} > csf_qvec.1D
  3dmaskave -mask ${func_seg_dir}/csf_mask.nii.gz -quiet ${func_input} > csf.1D
  ## 2.5. white matter
  echo "Extracting signal from white matter"
  3dmaskSVD -vnorm -mask ${func_seg_dir}/wm_mask.nii.gz -polort 0 ${func_input} > wm_qvec.1D
  3dmaskave -mask ${func_seg_dir}/wm_mask.nii.gz -quiet ${func_input} > wm.1D
  ## 2.6 CompCor file
  echo "Calculating CompCor components "
  fslmaths ${func_seg_dir}/wm_mask.nii.gz -add ${func_seg_dir}/csf_mask.nii.gz -mul ${func_reg_dir}/${rest}_pp_mask.nii.gz -bin tmp_csfwm_mask.nii.gz
  3dmaskSVD -vnorm -mask tmp_csfwm_mask.nii.gz -sval 4 -polort 0 ${func_input} > csfwm_qvec5.1D
  rm tmp_csfwm_mask.nii.gz
  ##  Seperate SVD parameters into seperate files
  awk '{print $1}' csfwm_qvec5.1D > compcor1.1D
  awk '{print $2}' csfwm_qvec5.1D > compcor2.1D
  awk '{print $3}' csfwm_qvec5.1D > compcor3.1D
  awk '{print $4}' csfwm_qvec5.1D > compcor4.1D
  awk '{print $5}' csfwm_qvec5.1D > compcor5.1D
  1dcat compcor1.1D compcor2.1D compcor3.1D compcor4.1D compcor5.1D > compcor_1-5.txt
  
  echo "Prepare different nuisance regression models"
  ## Concatenate regressor for the nuisance regression
  1dcat mc1.1D mc2.1D mc3.1D mc4.1D mc5.1D mc6.1D > mc_1-6.txt
  1dcat mcsqr1.1D mcsqr2.1D mcsqr3.1D mcsqr4.1D mcsqr5.1D mcsqr6.1D > mcsqr_1-6.txt
  1dcat mcar1.1D mcar2.1D mcar3.1D mcar4.1D mcar5.1D mcar6.1D > mcar_1-6.txt
  1dcat mcarsqr1.1D mcarsqr2.1D mcarsqr3.1D mcarsqr4.1D mcarsqr5.1D mcarsqr6.1D > mcarsqr_1-6.txt
  1dcat csf.1D wm.1D global.1D > csf_wm_global.txt
  # Motion + CSF + WM + (Global)
  if [ ${average_method} == "mean" ]; then
    1dcat mc_1-6.txt mcar_1-6.txt mcsqr_1-6.txt mcarsqr_1-6.txt csf.1D wm.1D > Model_Motion24_CSF_WM.txt
    1dcat mc_1-6.txt mcar_1-6.txt mcsqr_1-6.txt mcarsqr_1-6.txt csf.1D wm.1D global.1D > Model_Motion24_CSF_WM_Global.txt
    1dcat mc_1-6.txt mcar_1-6.txt csf.1D wm.1D > Model_Motion12_CSF_WM.txt
    1dcat mc_1-6.txt mcar_1-6.txt csf.1D wm.1D global.1D > Model_Motion12_CSF_WM_Global.txt
    1dcat mc_1-6.txt csf.1D wm.1D > Model_Motion6_CSF_WM.txt
    1dcat mc_1-6.txt csf.1D wm.1D global.1D > Model_Motion6_CSF_WM_Global.txt
  elif [ ${average_method} == "svd" ]; then
    1dcat mc_1-6.txt mcar_1-6.txt mcsqr_1-6.txt mcarsqr_1-6.txt csf_qvec.1D wm_qvec.1D > Model_Motion24_CSF_WM.txt
    1dcat mc_1-6.txt mcar_1-6.txt mcsqr_1-6.txt mcarsqr_1-6.txt csf_qvec.1D wm_qvec.1D global.1D > Model_Motion24_CSF_WM_Global.txt
    1dcat mc_1-6.txt mcar_1-6.txt csf_qvec.1D wm_qvec.1D > Model_Motion12_CSF_WM.txt
    1dcat mc_1-6.txt mcar_1-6.txt csf_qvec.1D wm_qvec.1D global.1D > Model_Motion12_CSF_WM_Global.txt
    1dcat mc_1-6.txt csf_qvec.1D wm_qvec.1D > Model_Motion6_CSF_WM.txt
    1dcat mc_1-6.txt csf_qvec.1D wm_qvec.1D global.1D > Model_Motion6_CSF_WM_Global.txt
  fi
  # Prepare Compcor
  1dcat mc_1-6.txt mcar_1-6.txt mcsqr_1-6.txt mcarsqr_1-6.txt compcor_1-5.txt > Model_Motion24_CompCor.txt
  1dcat mc_1-6.txt mcar_1-6.txt mcsqr_1-6.txt mcarsqr_1-6.txt compcor_1-5.txt global.1D > Model_Motion24_CompCor_Global.txt
  1dcat mc_1-6.txt mcar_1-6.txt compcor_1-5.txt > Model_Motion12_CompCor.txt
  1dcat mc_1-6.txt mcar_1-6.txt compcor_1-5.txt global.1D > Model_Motion12_CompCor_Global.txt
  1dcat mc_1-6.txt compcor_1-5.txt > Model_Motion6_CompCor.txt
  1dcat mc_1-6.txt compcor_1-5.txt global.1D > Model_Motion6_CompCor_Global.txt

  ## clean-up
  rm mc[1-6].1D mcar[1-6].1D mcarsqr[1-6].1D mcdt[1-6].1D mcsqr[1-6].1D compcor?.1D

  echo ">> Visualize the nuisance"
  1dplot -xlabel "Frame" -ylabel "headmotion (mm)" -yaxis -0.5:0.5:4:8 -png vcheck_motion_0.5.png mc_1-6.txt
  1dplot -xlabel "Frame" -ylabel "headmotion (mm)" -yaxis -1:1:4:8 -png vcheck_motion_1.png mc_1-6.txt
  1dplot -xlabel "Frame" -ylabel "roll:blk,pitch:r,yaw:g,dS:blue,dL:pink,dP:yellow" -one -png vcheck_motion.png mc_1-6.txt
  1dplot -xlabel "Frame" -ylabel "CSF(blk)/WM(r)/Global(g)" -demean -png vcheck_csf_wm_global.png csf_wm_global.txt
  1dplot -xlabel "Frame" -ylabel "Global" -demean -png vcheck_global.png global.1D
  1dplot -xlabel "Frame" -ylabel "Global" -demean -png vcheck_csf.png csf.1D
  1dplot -xlabel "Frame" -ylabel "Global" -demean -png vcheck_wm.png wm.1D
  1dplot -xlabel "Frame" -ylabel "CompCor" -norm2 -png vcheck_compcor.png compcor_1-5.txt
else
  echo "Note: the nuisance files are existing, skip..."
fi

cd ${cwd}



