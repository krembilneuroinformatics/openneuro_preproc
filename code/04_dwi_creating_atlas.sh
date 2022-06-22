#!/bin/sh

#Davide Momi 2022
# -----------
# Post-Doctoral Research Fellow
# Whole Brain Modelling Group
# Krembil Centre for Neuroinformatics - CAMH
# 250 College St., Toronto, ON M5T 1R8
# email momi.davide89@gmail.com
#website: https://davi1990.github.io/
#Twitter: @DaveMomi

export SUBJECTS_DIR=/external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/fs_directories/

data_dir=/external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/
cd $data_dir

#Loop over each subject and run preprocessing and DTI fitting
for parcels in `cat parcels2use.txt`; do
  for sub in `cat subjList.txt`; do
    length=${#parcels}
    cd $SUBJECTS_DIR/${sub}/

    SUBSTRING=$(echo $parcels| cut -d'_' -f 2 | rev | cut -c8- | rev)
    num1="$(($SUBSTRING/2))"
    num1="$((2001-$num1))"
    num1="$(($num1-1))"

    mri_surf2surf --hemi rh \
      --srcsubject fsaverage \
      --trgsubject ${sub} \
      --sval-annot /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/fs_directories/fsaverage/label/rh.${parcels} \
      --tval $SUBJECTS_DIR/${sub}/label/rh.${parcels}

    mri_surf2surf --hemi lh \
        --srcsubject fsaverage \
        --trgsubject ${sub} \
        --sval-annot /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/fs_directories/fsaverage/label/lh.${parcels} \
        --tval $SUBJECTS_DIR/${sub}/label/lh.${parcels}


    mri_aparc2aseg --s ${sub} \
                   --o $SUBJECTS_DIR/${sub}/mri/${parcels:0: length - 12}.mgz \
                   --annot ${parcels:0: length - 6}

    mrconvert $SUBJECTS_DIR/${sub}/mri/${parcels:0: length - 12}.mgz \
              /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school//Parcels2use/${sub}_${parcels:0: length - 12}.nii.gz


    fslmaths /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_${parcels:0: length - 12}.nii.gz \
              -thr 1000 $SUBJECTS_DIR/${sub}/first_step.nii.gz

    fslmaths $SUBJECTS_DIR/${sub}/first_step.nii.gz   \
              -roi 0 128 0 -1 0 -1 0 -1 \
              $SUBJECTS_DIR/${sub}/rh.nii.gz

    fslmaths $SUBJECTS_DIR/${sub}/rh.nii.gz \
            -thr 2001 \
            $SUBJECTS_DIR/${sub}/rh.nii.gz

    fslmaths $SUBJECTS_DIR/${sub}/rh.nii.gz \
            -sub ${num1} \
            $SUBJECTS_DIR/${sub}/rh.nii.gz

    fslmaths $SUBJECTS_DIR/${sub}/rh.nii.gz \
            -thr 1 \
            $SUBJECTS_DIR/${sub}/rh.nii.gz

    fslmaths /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_${parcels:0: length - 12}.nii.gz \
              -uthr 1999 \
              $SUBJECTS_DIR/${sub}/lh.nii.gz

    fslmaths $SUBJECTS_DIR/${sub}/lh.nii.gz \
              -thr 1001 \
              $SUBJECTS_DIR/${sub}/lh.nii.gz

    fslmaths $SUBJECTS_DIR/${sub}/lh.nii.gz \
            -sub 1000 \
            $SUBJECTS_DIR/${sub}/lh.nii.gz

    fslmaths $SUBJECTS_DIR/${sub}/lh.nii.gz \
              -thr 1 \
              $SUBJECTS_DIR/${sub}/lh.nii.gz


    fslmaths $SUBJECTS_DIR/${sub}/rh.nii.gz \
             -add $SUBJECTS_DIR/${sub}/lh.nii.gz \
             //external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school//Parcels2use/${sub}_${parcels:0: length - 12}_rewritten.nii.gz

    rm $SUBJECTS_DIR/${sub}/rh.nii.gz
    rm $SUBJECTS_DIR/${sub}/lh.nii.gz
    rm $SUBJECTS_DIR/${sub}/first_step.nii.gz

    mrconvert /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_${parcels:0: length - 12}_rewritten.nii.gz \
          -datatype uint32 \
          /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_${parcels:0: length - 12}_rewritten.nii.gz -force

   mri_convert /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/fs_directories/${sub}//mri/T1.mgz /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_T1w.nii.gz

   bet /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_T1w.nii.gz /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_T1w_brain -R -f 0.35 -g 0

   flirt -in /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_T1w_brain.nii.gz \
    	 -ref /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/${sub}/dwi/03_bet/${sub}_denoised_brain.nii.gz \
    	 -interp nearestneighbour \
         -omat /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/${sub}/dwi/struct2dwi.mat



  rm  /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_T1w.nii.gz
  rm /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_T1w_brain*
  flirt -ref /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/${sub}/dwi/03_bet/${sub}_denoised_brain.nii.gz\
        -in /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_${parcels:0: length - 12}_rewritten.nii.gz \
        -out /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/Parcels2use/${sub}_${parcels:0: length - 12}_rewritten_ref.nii.gz \
        -init /external/rprshnas01/netdata_kcni/jglab/Data/Davide/KCNI_summer_school/${sub}/dwi/struct2dwi.mat \
        -applyxfm -interp nearestneighbour
  done
done
