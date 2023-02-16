#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO DO FUNCTIONAL IMAGE Registration (FUNC to STD)
## Xi-Nian Zuo, Aug. 13, 2011; Revised at IPCAS, Feb. 12, 2013.
## Ting Xu 202204, BIDS format input
##########################################################################################################################

## ccs directory
ccs_dir=$1
## name of the anat directory
anat_dir=$2
## anat_reg_dir_name
anat_reg_dir_name=$3
## name of the resting-state scan
rest=$4
## name of the func directory
func_dir=$5
## func minimal preproc directory
func_min_dir_name=$6
## func reg directory name
func_reg_dir_name=$7
## resolution
res=$8
## if rerun
if_rerun=$9

## directory setup
anat_reg_dir=${anat_dir}/${anat_reg_dir_name}
func_min_dir=${func_dir}/${func_min_dir_name}
func_reg_dir=${func_dir}/${func_reg_dir_name}
highres=${anat_reg_dir}/highres.nii.gz
example_func=${func_reg_dir}/example_func_brain.nii.gz
## template
standard_head=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz
standard_brain=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz
standard_edge=${ccs_dir}/templates/MNI152_T1_brain_3dedge3_2mm.nii.gz # same resolution as standard_brain/head
standard_func=${ccs_dir}/templates/MNI152_T1_${res}mm.nii.gz


if [ $# -lt 8 ];
then
        echo -e "\033[47;35m Usage: $0 ccs_dir anat_dir_path anat_reg_dir_name (e.g. reg) func_name (e.g. func) func_dir_path func_minimal_dir_name (e.g. func_minimal) func_reg_dir_name (default: reg) resolution of func write out (e.g. 3 in mm) if_refun (default: true) \033[0m"
        exit
fi

echo "---------------------------------------"
echo "!!!! FUNC To STANDARD REGISTRATION !!!!"
echo "---------------------------------------"

if [ -z ${res} ]; then
  res=3
fi 

if [ -z ${if_rerun} ]; then
  if_rerun=true
fi

##------------------------------------------------
cwd=$( pwd )
##1. FUNC->STANDARD
cd ${func_reg_dir}
if [[ ! -f fnirt_example_func2standard.nii.gz ]] || [[ ${if_rerun} == "true" ]]; then
  echo ">> Concatenate func-anat-std registration"
  ## Create mat file for registration of functional to standard
  convert_xfm -omat example_func2standard.mat -concat ${anat_reg_dir}/highres2standard.mat example_func2highres.mat
  ## apply registration
  flirt -ref ${standard_brain} -in ${example_func} -out example_func2standard.nii.gz -applyxfm -init example_func2standard.mat -interp trilinear
  ## Create inverse mat file for registration of standard to functional
  convert_xfm -inverse -omat standard2example_func.mat example_func2standard.mat
  ## 5. Applying fnirt
  applywarp --interp=spline --ref=${standard_brain} --in=${example_func} --out=fnirt_example_func2standard.nii.gz --warp=${anat_reg_dir}/highres2standard_warp --premat=example_func2highres.mat 

  ## 5. Visual check
  ## vcheck of the fnirt registration
  echo "----- visual check of the functional registration ----"
  bg_min=`fslstats fnirt_example_func2standard.nii.gz -P 1`
  bg_max=`fslstats fnirt_example_func2standard.nii.gz -P 99`
  overlay 1 1 fnirt_example_func2standard.nii.gz ${bg_min} ${bg_max} ${standard_edge} 1 1 vcheck/render_vcheck
  slicer vcheck/render_vcheck -s 2 \
      -x 0.30 sla.png -x 0.45 slb.png -x 0.50 slc.png -x 0.55 sld.png -x 0.70 sle.png \
      -y 0.30 slg.png -y 0.40 slh.png -y 0.50 sli.png -y 0.60 slj.png -y 0.70 slk.png \
      -z 0.30 slm.png -z 0.40 sln.png -z 0.50 slo.png -z 0.60 slp.png -z 0.70 slq.png 
  pngappend sla.png + slb.png + slc.png + sld.png  +  sle.png render_vcheck1.png 
  pngappend slg.png + slh.png + sli.png + slj.png  + slk.png render_vcheck2.png
  pngappend slm.png + sln.png + slo.png + slp.png  + slq.png render_vcheck3.png
  pngappend render_vcheck1.png - render_vcheck2.png - render_vcheck3.png fnirt_example_func2standard_edge.png
  mv fnirt_example_func2standard_edge.png vcheck/
  title=fnirt_example2standard
  convert -font helvetica -fill white -pointsize 36 -draw "text 15,25 '$title'" vcheck/fnirt_example_func2standard.png vcheck/fnirt_example_func2standard.png
  rm -f sl?.png render_vcheck?.png vcheck/render_vcheck*

else
  echo ">> Concatenate func-anat-std registration (done, skip)"
fi

## Apply to the data
if [[ ! -f ${rest}_gms.mni152.${res}mm.nii.gz ]] || [[ "${if_rerun}" = "true" ]]; then 
  echo ">> Apply func-anat-std registration to the func dataset"
  applywarp --interp=nn --ref=${standard_func} --in=${rest}_pp_mask.nii.gz --out=${rest}_pp_mask.mni152.${res}mm.nii.gz --warp=${anat_reg_dir}/highres2standard_warp --premat=example_func2highres.mat

  applywarp --interp=spline --ref=${standard_func} --in=${rest}_gms.nii.gz --out=${rest}_gms.mni152.${res}mm.nii.gz --warp=${anat_reg_dir}/highres2standard_warp --premat=example_func2highres.mat
  mri_mask ${rest}_gms.mni152.${res}mm.nii.gz ${rest}_pp_mask.mni152.${res}mm.nii.gz ${rest}_gms.mni152.${res}mm.nii.gz
else
  echo ">> Apply func-anat-std registration to the func dataset (done, skip)"
fi

##--------------------------------------------
## Back to the directory
cd ${cwd}
