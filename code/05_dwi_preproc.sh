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

module load MRtrix3/0.3.15
module load FSL/6.0.4-centos7_64
module load  ANTS/2.1.3
module load bio/FreeSurfer/6.0.0-centos6_x86_64

FSLDIR=/opt/scc/apps/x86_64/software/FSL/6.0.4-centos7_64/
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${FSLDIR}/bin:${PATH}
export FSLDIR PATH


export SUBJECTS_DIR=/external/rprshnas01/netdata_kcni/jglab/Data/Davide/Banting/subjs_t1w/fs_directory

#Converts a diffusion-weighted image to an MRtrix file, and then runs denoising and eddy correction on the data

#Set Variables

#Replace data_dir with a path to my own directiory
data_dir=/external/rprshnas01/netdata_kcni/jglab/Data/Davide/Banting/DWI/
cd ${data_dir}

#If the file SubjList.txt doen't exist, create it
if [ ! -f subjList.txt ]; then
ls | grep ^sub- > subjList.txt
fi



#Loop over each subject and run preprocessing and DTI fitting
for subj in `cat subjList.txt`; do

#Navigate to the directory containing the diffusion data
#Note that the directory hierarchy is assumed to be subjectName/dwi;
cd ${data_dir}/${subj}

#1) Convert the NIFTI file to MIF format
echo "Convert the NIFTI file to MIF format for ${sub}"
mkdir ./01_mrconvert
fslroi ${subj}_dwi.nii.gz ${subj}_nodif.nii.gz 0 1
mrconvert -fslgrad ${subj}_dwi.bvec ${subj}_dwi.bval ${subj}_dwi.nii.gz ./01_mrconvert/${subj}.mif -force
#echo "Done successfully"
#
# 2)Denoise the data
#echo "Denoise the data for ${subj}"
mkdir ./02_dwidenoise
dwidenoise ./01_mrconvert/${subj}.mif ./02_dwidenoise/${subj}_denoised.mif -noise ./02_dwidenoise/${subj}_noise.mif -force
echo "Done successfully"
#
# #3)Also create a copy of NIFTI format for examine it in fsleyes
#echo "Also create a copy of NIFTI format for examine it in fsleyes for ${subj}"
mrconvert ./02_dwidenoise/${subj}_noise.mif ./02_dwidenoise/${subj}_noise.nii -force
mrconvert ./02_dwidenoise/${subj}_denoised.mif ./02_dwidenoise/${subj}_denoised.nii -force
#echo "Done successfully"
#
# #4)Calculate the resuduals. The output, res.nii, can be loaded in fsleyes; if the denoising did a good job, there should be #little or no anatomy in the residual maps for the diffusion weighted images (this does not apply to the initial b0 image)
#echo "Calculate the resuduals for ${subj}"
mrcalc ${subj}_dwi.nii.gz ./02_dwidenoise/${subj}_denoised.mif -subtract ./02_dwidenoise/${subj}_res.nii -force
#echo "Done successfully"


#
# #5)Run BET on subjects data and create a mask
echo "Run BET for ${subj}"
mkdir ./03_bet
bet ./${subj}_nodif.nii.gz ./03_bet/${subj}_denoised_brain.nii.gz -R -f 0.1 -g 0 -m
echo "Done successfully"

#6)Run eddy on the data to correct for eddy currents and fix slices corrupted by motion
echo "Run EDDY for motion and distortion correction for ${subj}"
mkdir ./04_eddy
eddy_openmp --imain=./02_dwidenoise/${subj}_denoised.nii --mask=./03_bet/${subj}_denoised_brain_mask.nii.gz --index=${data_dir}/index.txt --acqp=${data_dir}acqparams.txt --bvecs=${subj}_dwi.bvec --bvals=${subj}_dwi.bval --out=./04_eddy/${subj}_dwi_denoised_eddy --data_is_shelled -v
echo "Done successfully"
#
#
# #8)improve downstream brain mask estimation with bias field correction
# #echo "Improving downstream brain mask estimation with bias field correction for ${subj}"
mkdir ./05_bias_field_correction
dwibiascorrect -ants ./04_eddy/${subj}_dwi_denoised_eddy.nii.gz ./05_bias_field_correction/${subj}_dwi_denoised_eddy_unbiased.mif -fslgrad ./04_eddy/${subj}_dwi_denoised_eddy.eddy_rotated_bvecs ${subj}_dwi.bval -bias ./05_bias_field_correction/${subj}_bias.mif
echo "Done successfully"

mri_convert ${SUBJECTS_DIR}/${subj}/mri/T1.mgz T1w.nii.gz
bet T1w.nii.gz T1w_brain -R -f 0.35 -g 0

flirt -in T1w_brain.nii.gz \
    -ref ./03_bet/${subj}_denoised_brain.nii.gz \
    -interp nearestneighbour \
    -omat struct2dwi.mat


5ttgen fsl T1w_brain.nii.gz 5TT.mif -premasked


#9)Response function estimation
#echo "Estimating Response function for ${subj}"
mkdir ./06_csd
dwi2response msmt_5tt ./05_bias_field_correction/${subj}_dwi_denoised_eddy_unbiased.mif 5TT.mif \
              -fslgrad ./04_eddy/${subj}_dwi_denoised_eddy.eddy_rotated_bvecs ${subj}_dwi.bval \
              ./06_csd/RF_WM.txt ./06_csd/RF_GM.txt ./06_csd/RF_CSF.txt -voxels ./06_csd/RF_voxels.mif
echo "Done successfully"

#10)make a mask
dwi2mask ./05_bias_field_correction/${subj}_dwi_denoised_eddy_unbiased.mif -fslgrad ./04_eddy/${subj}_dwi_denoised_eddy.eddy_rotated_bvecs ${subj}_dwi.bval ./06_csd/${subj}_mask.mif
echo "Done successfully"

#11)Estimation of Fiber Orientation Distributions (FOD)
#echo "Estimating Fiber Orientation Distributions for ${subj}"
dwi2fod msmt_csd ./05_bias_field_correction/${subj}_dwi_denoised_eddy_unbiased.mif  \
       -fslgrad ./04_eddy/${subj}_dwi_denoised_eddy.eddy_rotated_bvecs ${subj}_dwi.bval \
        ./06_csd/RF_WM.txt ./06_csd/WM_FODs.mif ./06_csd/RF_GM.txt ./06_csd/GM.mif ./06_csd/RF_CSF.txt \
        ./06_csd/CSF.mif -mask ./06_csd/${subj}_mask.mif
echo "Done successfully"

mkdir 07_ACT
dwiextract ./05_bias_field_correction/${subj}_dwi_denoised_eddy_unbiased.mif ./07_ACT/pippo.mif -bzero
mrmath ./07_ACT/pippo.mif mean -axis 3 ./07_ACT/${subj}_mean_b0_preprocessed.mif
rm ./07_ACT/pippo.mif

mrconvert ./07_ACT/${subj}_mean_b0_preprocessed.mif ./07_ACT/${subj}_mean_b0_preprocessed.nii.gz
cp 5TT.mif ./07_ACT/${subj}_5tt_nocoreg.mif
mrconvert ./07_ACT/${subj}_5tt_nocoreg.mif ./07_ACT/${subj}_5tt_nocoreg.nii.gz

flirt -in ./07_ACT/${subj}_mean_b0_preprocessed.nii.gz -ref ./07_ACT/${subj}_5tt_nocoreg.nii.gz -interp nearestneighbour -dof 6 -omat ./07_ACT/${subj}_diff2struct_fsl.mat

transformconvert ./07_ACT/${subj}_diff2struct_fsl.mat ./07_ACT/${subj}_mean_b0_preprocessed.nii.gz ./07_ACT/${subj}_5tt_nocoreg.nii.gz flirt_import ./07_ACT/${subj}_diff2struct_mrtrix.txt

mrtransform ./07_ACT/${subj}_5tt_nocoreg.mif -linear ./07_ACT/${subj}_diff2struct_mrtrix.txt -inverse ./07_ACT/${subj}_5tt_coreg.mif


#Now we will create a mask to define where our streamlines should start! Again, from anatomy, we know that the gray-matter/white-matter-boundary should be a reasonable starting point

5tt2gmwmi ./07_ACT/${subj}_5tt_coreg.mif ./07_ACT/${subj}_gmwmSeed_coreg.mif




flirt -in /external/rprshnas01/netdata_kcni/jglab/Data/Davide/Banting/fMRI//${subj}/Schaefer2018_200Parcels_7Networks_rewritten.nii.gz \
       -ref ./03_bet/${subj}_denoised_brain.nii.gz \
       -interp nearestneighbour \
       -out $data_dir/${subj}/Schaefer2018_200Parcels_7Networks_rewritten_reg2dwi.nii.gz  \
       -init struct2dwi.mat -applyxfm

tckgen WM_FODs.mif 5M.tck -act 5TT.mif -backtrack -crop_at_gmwmi -seed_dynamic \
        WM_FODs.mif -maxlength 250 -select 5M -cutoff 0.06




cd ../..
done
