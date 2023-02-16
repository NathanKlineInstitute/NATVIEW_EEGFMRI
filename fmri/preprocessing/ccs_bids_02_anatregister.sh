#!/usr/bin/env bash
##########################################################################################################################
## CCS SCRIPT TO DO IMAGE REGISTRATION (FLIRT/FNIRT)
##
## !!!!!*****ALWAYS CHECK YOUR REGISTRATIONS*****!!!!!
##
## R-fMRI master: Xi-Nian Zuo. Dec. 07, 2010, Institute of Psychology, CAS.
##
## Email: zuoxn@psych.ac.cn or zuoxinian@gmail.com.
## Ting Xu: add 3dedge for the plot
##########################################################################################################################

## ccs_dir
ccs_dir=$1
## anat directory
anat_dir=$2
## SUBJECTS_DIR
SUBJECTS_DIR=$3
## subject
subject=$4
## name of anatomical registration directory
anat_reg_dir_name=$5

if [ $# -lt 4 ];
then
        echo -e "\033[47;35m Usage: $0 subject analysis_dir session_name ccs_dir\033[0m"
        exit
fi

if [ $# -lt 5 ];
then
        anat_reg_dir_name=reg
fi

## directory example
# anat_dir=${dir}/${subject}/${session_name}/anat
# SUBJECTS_DIR=${dir}/${subject}/${session_name} #FREESURFER SETUP

## directory setup
anat_reg_dir=${anat_dir}/${anat_reg_dir_name}
anat_seg_dir=${anat_dir}/segment
### setup standard
standard_head=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz
standard=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz
standard_mask=${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask_dil.nii.gz
standard_3dedge3=${ccs_dir}/templates/MNI152_T1_brain_3dedge3_2mm.nii.gz

echo -----------------------------------------
echo !!!! RUNNING ANATOMICAL REGISTRATION !!!!
echo -----------------------------------------

mkdir -p ${anat_reg_dir} ; cd ${anat_reg_dir}
if [ ! -f fnirt_highres2standard.nii.gz ]; then

	## 1. Prepare anatomical images
	mri_convert -it mgz ${SUBJECTS_DIR}/${subject}/mri/rawavg.mgz -ot nii tmp_head.nii.gz

	if [ ! -f ${anat_seg_dir}/brainmask.nii.gz ]
	then
		mkdir -p ${anat_seg_dir}
		mri_convert -it mgz ${SUBJECTS_DIR}/${subject}/mri/brainmask.mgz -ot nii ${anat_seg_dir}/brainmask.nii.gz
        	mri_convert -it mgz ${SUBJECTS_DIR}/${subject}/mri/T1.mgz -ot nii ${anat_seg_dir}/T1.nii.gz
	fi
        rm -fv ${anat_reg_dir}/highres_head.nii.gz
	3dresample -master ${anat_seg_dir}/brainmask.nii.gz -rmode Linear -prefix ${anat_reg_dir}/highres_head.nii.gz -inset tmp_head.nii.gz
	fslmaths ${anat_seg_dir}/brainmask.nii.gz -thr 2 ${anat_seg_dir}/brainmask.nii.gz #clean voxels manually edited in freesurfer (assigned value 1)
	fslmaths highres_head.nii.gz -mas ${anat_seg_dir}/brainmask.nii.gz highres.nii.gz ; rm -vf tmp_head.nii.gz

	## 2. FLIRT T1->STANDARD
	fslreorient2std highres.nii.gz highres_rpi.nii.gz
	flirt -ref ${standard} -in highres_rpi -out highres_rpi2standard -omat highres_rpi2standard.mat -cost corratio -searchcost corratio -dof 12 -interp trilinear
	rm -vf highres_rpi_3dedge3.nii.gz
        3dedge3 -input highres_rpi.nii.gz -prefix highres_rpi_3dedge3.nii.gz
	## Create mat file for conversion from standard to high res
	fslreorient2std highres.nii.gz > rsp2rpi.mat
        convert_xfm -omat rpi2rsp.mat -inverse rsp2rpi.mat
	convert_xfm -omat highres2standard.mat -concat highres_rpi2standard.mat rsp2rpi.mat 
	convert_xfm -inverse -omat standard2highres.mat highres2standard.mat
	## 3. FNIRT
	echo "Performing nolinear registration ..."
	fnirt --in=highres_head --aff=highres2standard.mat --cout=highres2standard_warp --iout=fnirt_highres2standard --jout=highres2standard_jac --config=T1_2_MNI152_2mm --ref=${standard_head} --refmask=${standard_mask} --warpres=10,10,10 > warnings.fnirt
	if [ -s ${anat_reg_dir}/warnings.fnirt ]
	then
		mv fnirt_highres2standard.nii.gz fnirt_highres2standard_wres10.nii.gz
		fnirt --in=highres_head --aff=highres2standard.mat --cout=highres2standard_warp --iout=fnirt_highres2standard --jout=highres2standard_jac --config=T1_2_MNI152_2mm --ref=${standard_head} --refmask=${standard_mask} --warpres=20,20,20
	else
		rm -v warnings.fnirt
	fi
else
	echo "SKIP >> The (flirt+fnirt) registration has been done for this subject!"
fi


if [ ! -f vcheck/fnirt_highres2standard_Ref-AnatBoundary.png ]; then
        ## 4. vcheck the registration quality
        cd ${anat_reg_dir}
        mkdir vcheck
        ## vcheck of the functional registration
        echo "-----visual check of the fnirt registration-----"
        rm -f sl?.png render_vcheck?.png
        bg_min=`fslstats fnirt_highres2standard.nii.gz -P 2`
        bg_max=`fslstats fnirt_highres2standard.nii.gz -P 98`
        overlay 1 1 fnirt_highres2standard.nii.gz ${bg_min} ${bg_max} ${standard_3dedge3} 1 1 vcheck/render_vcheck
        slicer vcheck/render_vcheck -s 2 \
           -x 0.30 sla.png -x 0.45 slb.png -x 0.50 slc.png -x 0.55 sld.png -x 0.70 sle.png \
           -y 0.30 slg.png -y 0.40 slh.png -y 0.50 sli.png -y 0.60 slj.png -y 0.70 slk.png \
           -z 0.30 slm.png -z 0.40 sln.png -z 0.50 slo.png -z 0.60 slp.png -z 0.70 slq.png 
        pngappend sla.png + slb.png + slc.png + sld.png  +  sle.png render_vcheck1.png 
        pngappend slg.png + slh.png + sli.png + slj.png  + slk.png render_vcheck2.png
        pngappend slm.png + sln.png + slo.png + slp.png  + slq.png render_vcheck3.png
        pngappend render_vcheck1.png - render_vcheck2.png - render_vcheck3.png fnirt_highres2standard.png
        title=${subject}.${session_name}.Anat-RefBoundary
        convert -font helvetica -fill white -pointsize 36 -draw "text 30,50 '$title'" fnirt_highres2standard.png fnirt_highres2standard.png
        mv fnirt_highres2standard.png vcheck/fnirt_highres2standard_Anat-RefBoundary.png

        slicer ${standard} fnirt_highres2standard -s 2 \
           -x 0.30 sla.png -x 0.40 slb.png -x 0.50 slc.png -x 0.60 sld.png -x 0.70 sle.png \
           -y 0.30 slg.png -y 0.40 slh.png -y 0.50 sli.png -y 0.60 slj.png -y 0.70 slk.png \
           -z 0.30 slm.png -z 0.40 sln.png -z 0.50 slo.png -z 0.60 slp.png -z 0.70 slq.png
        pngappend sla.png + slb.png + slc.png + sld.png  +  sle.png render_vcheck1.png 
        pngappend slg.png + slh.png + sli.png + slj.png  + slk.png render_vcheck2.png
        pngappend slm.png + sln.png + slo.png + slp.png  + slq.png render_vcheck3.png
        pngappend render_vcheck1.png - render_vcheck2.png - render_vcheck3.png fnirt_highres2standard.png
        title=${subject}.${session_name}.Ref-AnatBoundary
        convert -font helvetica -fill white -pointsize 36 -draw "text 30,50 '$title'" fnirt_highres2standard.png fnirt_highres2standard.png
        mv fnirt_highres2standard.png vcheck/fnirt_highres2standard_Ref-AnatBoundary.png
        rm -f sl?.png render_vcheck?.png  

else
	echo "The vcheck for the registration has been done for this subject!"
fi

cd ${cwd}
