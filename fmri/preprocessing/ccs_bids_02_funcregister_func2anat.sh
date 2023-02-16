#!/usr/bin/env bash

##########################################################################################################################
## CCS SCRIPT TO DO Boundary-based FUNCTIONAL IMAGE Registration
## Revised from Xi-Nian Zuo https://github.com/zuoxinian/CCS
## Ting Xu 202204, BIDS format input
##########################################################################################################################

## name of the anat directory
anat_dir=$1
## anat_reg_dir_name
anat_reg_dir_name=$2
## FS SUBJECTS_DIR
SUBJECTS_DIR=$3
## subject
subject=$4
## name of the resting-state scan
rest=$5
## name of the func directory
func_dir=$6
## func_minimal_preproc_dir_name: func_minimal
func_min_dir_name=$7
## func reg method
reg_method=$8 # fsbbr flirtbbr flirt
## func reg directory name
func_reg_dir_name=$9
## if use the bias field corrected example_func_brain to do alignment
if_use_bc=${10}
## resolution
res=${11}
## redo_reg
redo_reg=${12}

## directory setup
anat_reg_dir=${anat_dir}/${anat_reg_dir_name}
func_min_dir=${func_dir}/${func_min_dir_name}
func_reg_dir=${func_dir}/${func_reg_dir_name}
highres=${anat_reg_dir}/highres.nii.gz

if [ $# -lt 6 ];
then
        echo -e "\033[47;35m Usage: $0 anat_dir_path anat_reg_dir_name SUBJECTS_DIR subID func_name func_dir_path func_min_dir_name (default: func_minimal) reg_method (fsbbr[default], flirtbbr, flirt) func_reg_dir_name(default: reg) if_use_BiasFieldCorrected_example_func_brain resolution(default:3 in mm) redo_reg (default:true) \033[0m"
        exit
fi

echo "---------------------------------------"
echo "!!!! FUNC To ANAT REGISTRATION !!!!"
echo "---------------------------------------"

## check the input: reg_method options: fsbbr fslbbr flirt
if [ -z ${reg_method} ]; then
  reg_method=fsbbr
fi

if [ -z ${if_use_bc} ]; then
  echo "func volume used for registration: bias field corrected example_func_brain_bc"
  if_use_bc=true
fi

if [ -z ${res} ]; then
  res=3
fi 

if [ -z ${redo_reg} ]; then
  redo_reg=true
fi

cwd=$( pwd )

if [[ ${reg_method} != "fsbbr" ]] && [[ ${reg_method} != "flirtbbr" ]] && [[ ${reg_method} != "flirt" ]]; then
  echo "!!! Check and select the registration method option (reg_method): fsbbr, flirtbbr, flirt"
  exit
fi

##---------------------------------------------
if [[ ! -d ${func_reg_dir} ]]; then 
  mkdir ${func_reg_dir}
fi
cd ${func_reg_dir}

##---------------------------------------------
## If redo the registration step
if [[ ${redo_reg} == "true" ]] || [[ ! -f ${func_reg_dir}/example_func2highres_rpi.nii.gz ]]; then
  rm -r ${func_reg_dir}/*
  
  ##---------------------------------------------
  ## select the func volume for registration
  if [ ${if_use_bc} = 'true' ]; then
    echo "func volume used for registration: example_func_brain_bc (bias corrected)"
    mov=${func_min_dir}/example_func_brain_bc.init.nii.gz
  else
    echo "func volume used for registration: example_func_brain"
    mov=${func_min_dir}/example_func_brain.init.nii.gz
  fi
  
  ## convert the example_func to RSP orient
  rm -f ${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz
  3dresample -orient RSP -prefix ${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz -inset ${mov}
  fslreorient2std ${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz > ${func_reg_dir}/func_rsp2rpi.mat
  convert_xfm -omat ${func_reg_dir}/func_rpi2rsp.mat -inverse ${func_reg_dir}/func_rsp2rpi.mat
  
  ##---------------------------------------------
  ## do FS bbregister
  if [[ ${reg_method} == "fsbbr" ]]; then
    echo "-----------------------------------------------------"
    echo "func->anat registration method: Freesurfer bbregister"
    echo "-----------------------------------------------------"
    if [[ -f ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz ]]; then
      ## do fs bbregist
      mov_rsp=${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz
      bbregister --s ${subject} --mov ${mov_rsp} --reg bbregister_rsp2rsp.dof6.init.dat --init-fsl --bold --fslmat xfm_func_rsp2highres.init.mat
      bb_init_mincost=`cut -c 1-8 bbregister_rsp2rsp.dof6.init.dat.mincost`
      comp=`expr ${bb_init_mincost} \> 0.55`
      if [ "$comp" -eq "1" ]; then
        bbregister --s ${subject} --mov ${mov_rsp} --reg bbregister_rsp2rsp.dof6.dat --init-reg bbregister_rsp2rsp.dof6.init.dat --bold --fslmat xfm_func_rsp2highres.mat
        bb_mincost=`cut -c 1-8 bbregister_rsp2rsp.dof6.dat.mincost`
        comp=`expr ${bb_mincost} \> 0.55`
        if [ "$comp" -eq "1" ]; then
          echo "BBregister seems still problematic, needs a posthoc visual inspection!" >> warnings.bbregister
        fi
      else
        mv ${func_reg_dir}/bbregister_rsp2rsp.dof6.init.dat ${func_reg_dir}/bbregister_rsp2rsp.dof6.dat 
        mv ${func_reg_dir}/xfm_func_rsp2highres.init.mat ${func_reg_dir}/xfm_func_rsp2highres.mat
      fi
      ## concat reg matrix: func_rpi to highres(rsp)
      convert_xfm -omat ${func_reg_dir}/xfm_func2highres.mat -concat ${func_reg_dir}/xfm_func_rsp2highres.mat ${func_reg_dir}/func_rpi2rsp.mat
      ## write func_rpi to highres(rsp) to fs registration format 
      tkregister2 --mov ${mov} --targ ${highres} --fsl ${func_reg_dir}/xfm_func2highres.mat --noedit --s ${subject} --reg ${func_reg_dir}/bbregister.dof6.dat
    else
      echo "bbregister: Please check FreeSurfer recon-all for this subject first"
      echo "FS bbregister Warning: recon-all might fail. Run flirtbbr with FSL FAST segmentation for this func dataset" >> ${func_dir}/func_preproc.log
      reg_method=flirtbbr
    fi
  fi
  
  ##---------------------------------------------
  ## do flirt -bbr
  if [[ ${reg_method} == "flirtbbr" ]]; then
    echo "-----------------------------------------------------"
    echo "func->anat registration method: FSL flirt -bbr"
    echo "-----------------------------------------------------"
    ## prepare wmseg mask file
    if [[ ! -f ${SUBJECTS_DIR}/${subject}/mri/aseg.mgz ]]; then
      echo "Use FS wm mask"
      highres_wmseg=${anat_dir}/segment/segment_wm.nii.gz
    else
      echo "USE FSL FAST wm mask"
      highres_wmseg=${anat_dir}/segment_fast/segment_wm.nii.gz
    fi
    ## do flirt to init
    mov_rsp=${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz
    flirt -in ${mov_rsp} -ref ${highres} -cost corratio -omat ${func_reg_dir}/xfm_func_rsp2highres.flirt_init.mat -dof 6
    ## do flirt -bbr
    flirt -in ${mov_rsp} -ref ${highres} -cost bbr -wmseg ${highres_wmseg} -omat ${func_regbbr_dir}/xfm_func_rsp2highres.mtx -dof 6 -init ${func_reg_dir}/xfm_func_rsp2highres.flirt_init.mat
    convert_xfm -omat ${func_reg_dir}/flirt.mtx -concat ${func_reg_dir}/flirt_rsp2rsp.mat ${func_reg_dir}/rpi2rsp.mat
    ## write func_rpi to highres(rsp) to fs registration format
    tkregister2 --mov ${mov} --targ ${highres} --fsl ${func_reg_dir}/xfm_func2highres.mat --noedit --s ${subject} --reg ${func_regbbr_dir}/bbregister.dof6.dat
  fi
  
  ##---------------------------------------------
  ## do flirt
  if [ ${reg_method} == "flirt" ]; then
    echo "-----------------------------------------------------"
    echo "func->anat registration method: FSL flirt"
    echo "-----------------------------------------------------"
    mov_rsp=${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz
    flirt -in ${mov_rsp} -ref ${highres} -cost corratio -omat ${func_reg_dir}/xfm_func_rsp2highres.mat -dof 6
    convert_xfm -omat ${func_reg_dir}/xfm_func2highres.mat -concat ${func_reg_dir}/xfm_func_rsp2highres.mat ${func_reg_dir}/func_rpi2rsp.mat
    ## write func_rpi to highres(rsp) to fs registration format
    tkregister2 --mov ${mov} --targ ${highres} --fsl ${func_reg_dir}/xfm_func2highres.mat --noedit --s ${subject} --reg ${func_reg_dir}/bbregister.dof6.dat
  fi

  ##---------------------------------------------
  ## copy the xfm_*.mat matrix to example_func2highres 
  cp xfm_func2highres.mat example_func2highres.mat
  ## Create mat file for conversion from subject's anatomical to functional
  convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat
  rm -f ${func_reg_dir}/tmp_example_func_brain_rsp.nii.gz
  convert_xfm -omat example_func2highres_rpi.mat -concat ${anat_reg_dir}/rsp2rpi.mat example_func2highres.mat
  convert_xfm -inverse -omat highres_rpi2example_func.mat example_func2highres_rpi.mat

else
  echo ">> func-anat registration (done, skip)"
fi

#---------------------------------------------------
## refine the func_pp_mask using the func reg
if [ ! -f ${rest}_pp_mask.nii.gz ] || [[ ${redo_reg} == "true" ]]; then
  ##------------------------------------------------
  ## refine brain mask 
  echo ">> refine func_pp_mask based on func-anat registration "
  cp ${func_min_dir}/example_func.nii.gz ${func_reg_dir}/
  cp ${func_min_dir}/example_func_bc.nii.gz ${func_reg_dir}/
  flirt -ref example_func.nii.gz -in ${highres} -out tmpT1.nii.gz -applyxfm -init highres2example_func.mat -interp trilinear
  fslmaths tmpT1.nii.gz -bin tmpMask.nii.gz
  fslmaths ${func_min_dir}/${rest}_mc.nii.gz -Tstd -bin ${rest}_pp_mask.nii.gz
  fslmaths ${rest}_pp_mask.nii.gz -mul ${func_min_dir}/${rest}_mask.initD.nii.gz -mul tmpMask.nii.gz ${rest}_pp_mask.nii.gz -odt char
  rm -v tmpT1.nii.gz tmpMask.nii.gz

  ## apply the registration (func->anat)
  fslmaths example_func.nii.gz -mas ${rest}_pp_mask.nii.gz example_func_brain.nii.gz
  fslmaths example_func_bc.nii.gz -mas ${rest}_pp_mask.nii.gz example_func_brain_bc.nii.gz
  flirt -in example_func_brain.nii.gz -ref ${anat_reg_dir}/highres_rpi.nii.gz -applyxfm -init example_func2highres_rpi.mat -out example_func2highres_rpi.nii.gz -interp spline

  ##------------------------------------------------
  ## 3. visual check 
  mkdir ${func_reg_dir}/vcheck
  cd ${func_reg_dir}
  ## vcheck of the functional registration
  echo "-----------------------------------------------------"
  echo ">> visual check of the functional registration"
  echo "-----------------------------------------------------"
  bg_min=`fslstats example_func2highres_rpi.nii.gz -P 1`
  bg_max=`fslstats example_func2highres_rpi.nii.gz -P 99`
  overlay 1 1 example_func2highres_rpi.nii.gz ${bg_min} ${bg_max} ${anat_reg_dir}/highres_rpi_3dedge3.nii.gz 1 1 vcheck/render_vcheck
  slicer vcheck/render_vcheck -s 2 \
      -x 0.30 sla.png -x 0.45 slb.png -x 0.50 slc.png -x 0.55 sld.png -x 0.70 sle.png \
      -y 0.30 slg.png -y 0.40 slh.png -y 0.50 sli.png -y 0.60 slj.png -y 0.65 slk.png \
      -z 0.40 slm.png -z 0.50 sln.png -z 0.60 slo.png -z 0.70 slp.png -z 0.80 slq.png 
  pngappend sla.png + slb.png + slc.png + sld.png  +  sle.png render_vcheck1.png 
  pngappend slg.png + slh.png + sli.png + slj.png  + slk.png render_vcheck2.png
  pngappend slm.png + sln.png + slo.png + slp.png  + slq.png render_vcheck3.png
  pngappend render_vcheck1.png - render_vcheck2.png - render_vcheck3.png example_func2highres_rpi.png
  mv example_func2highres_rpi.png vcheck/
  title=example_func2highres_rpi
  convert -font helvetica -fill white -pointsize 36 -draw "text 30,50 '$title'" vcheck/example_func2highres_rpi.png vcheck/example_func2highres_rpi.png
  rm -f sl?.png render_vcheck?.png vcheck/render_vcheck*

else
  echo ">> refine func_pp_mask based on func-anat registration (done, skip)"
  echo ">> visualize func-anat vcheck figure (done, skip)"
fi 

##-------------------------------------------
cd ${func_reg_dir}
## 4. Skull Strip the func dataset
if [[ ! -f ${rest}_gms.nii.gz ]] || [[ ${redo_reg} == "true" ]] ; then
  echo ">> Skullstrip the func dataset using the refined rest_pp_mask"
  rm -f ${rest}_ss.nii.gz
  mri_mask ${func_min_dir}/${rest}_mc.nii.gz ${rest}_pp_mask.nii.gz ${rest}_ss.nii.gz
  fslmaths ${rest}_ss.nii.gz -ing 10000 ${rest}_gms.nii.gz
else
  echo ">> Skullstrip strip the func dataset using the refined rest_pp_mask (done, skip)"
fi

##--------------------------------------------
## 6. Apply registration, skull stripping and global scaling on the func data, func->anat
if [[ ! -f ${rest}_gms.anat.${res}mm.nii.gz ]] || [[ ${redo_reg} == "true" ]]; then
  echo ">> Apply func-anat registration to the mask"
  # create reference (in anat space with low-resolution, default 3mm)
  flirt -interp spline -in ${anat_reg_dir}/highres_rpi.nii.gz -ref ${anat_reg_dir}/highres_rpi.nii.gz -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat -applyisoxfm ${res} -out highres_rpi.${res}mm.nii.gz
  flirt -interp nearestneighbour -in ${rest}_pp_mask.nii.gz -ref ${anat_reg_dir}/highres_rpi.nii.gz -applyxfm -init example_func2highres_rpi.mat -applyisoxfm ${res} -out ${rest}_pp_mask.anat.${res}mm.nii.gz

  echo ">> Apply func-anat registration to the func dataset"
  flirt -interp spline -in ${rest}_gms.nii.gz -ref highres_rpi.${res}mm.nii.gz -applyxfm -init example_func2highres_rpi.mat -out ${rest}_gms.anat.${res}mm.nii.gz 
  mri_mask ${rest}_gms.anat.${res}mm.nii.gz ${rest}_pp_mask.anat.${res}mm.nii.gz ${rest}_gms.anat.${res}mm.nii.gz
else
  echo ">> Apply func-anat registration to the maks and func dataset (done, skip)"
fi

##--------------------------------------------
## Back to the directory
cd ${cwd}
