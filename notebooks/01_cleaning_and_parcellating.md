
using the ciftify container

```
#!/bin/bash
#SBATCH --partition=low-moby
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:30:00
#SBATCH --export=ALL
#SBATCH --job-name="cifti_parcellate"
#SBATCH --output=cifti_parcellate_%j.txt
#SBATCH --array=1-87


sublist=/scratch/jcyu/SPASD_code/sublist.txt

index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist \
   | tail -n 1
}

sub=`index`
sub=$(echo "$sub" | tr -d '\r')

# TODO: Will need to change this to your own directories!
input_folder=/scratch/jcyu/SPASD_cleaned_rest
output_folder=/scratch/edickie/SPASD_parcellated
sing_home=$(mktemp -d -t wb-XXXXXXXXXX)


ciftify_container=/archive/code/containers/FMRIPREP_CIFTIFY/tigrlab_fmriprep_ciftify_1.3.0.post2-2.3.1-2019-04-04-8ebe3500bebf.img
config_json=/scratch/jcyu/SPASD_code/SPASD_rest_clean.json
fmriprep_folder=/scratch/jcyu/SPASD_fmriprep
ciftify_folder=/scratch/jcyu/SPASD_ciftify

## note the dlabel file path must be a relative to the output folder
dlabel_file="tpl-fsLR/tpl-fsLR_den-32k_atlas-Glasser2016Tian2019_desc-subcortexS2_dseg.dlabel.nii"
atlas="atlas-GlasserTianS2"

# task_dir=$(find ${output}/ciftify/`index`/MNINonLinear/Results/ -type d -name "ses-0*_task-rest*")
task_dir=$(find ${ciftify_folder}/${sub}/MNINonLinear/Results/ -type d -name "ses-0*_task-rest*")

for ff in ${task_dir};
do
func_base=$(basename ${ff})
run="$(cut -f3 -nd "_" <<< "$func_base")"
ses="$(cut -f1 -nd "_" <<< "$func_base")"
dtseries=${ciftify_folder}/${sub}/MNINonLinear/Results/${func_base}/${func_base}_Atlas_s0
container_dtseries=/ciftify/${sub}/MNINonLinear/Results/${func_base}/${func_base}_Atlas_s0

echo $dtseries
echo $container_dtseries


mkdir -p ${output_folder}/${atlas}/ptseries/${sub}
mkdir -p ${output_folder}/${atlas}/csv/${sub}

singularity exec \
-H ${tmpdir}/home \
-B ${outdir}:/output \
-B ${HCP_S1200_dir}:/input \
${ciftify_container} ciftify_clean_img \
    --output-file=/output/${subject}/${subject}_${task}_Atlas${isMSM}_hp2000_clean2sm0.dtseries.nii \
    --clean-config=/output/HCP_12mp_3CleanPhys_filter.json \
    --confounds-tsv=/output/${subject}/${task}_mergetxt.tsv \
    /input/${subject}/MNINonLinear/Results/${task}/${task}_Atlas${isMSM}_hp2000_clean.dtseries.nii

singularity exec \
-H ${sing_home} \
-B ${input_folder}:/input_folder \
-B ${output_folder}:/output_folder \
${ciftify_container} wb_command -cifti-parcellate \
  /input_folder/${sub}/2_mm/${sub}_${ses}_task-rest_${run}_desc-cleansm2_bold.dtseries.nii \
  /output_folder/${dlabel_file} \
  COLUMN \
  /output_folder/${atlas}/ptseries/${sub}/${sub}_${ses}_task-rest_${atlas}_desc-cleanwGSRsm2_bold.ptseries.nii \
  -include-empty

singularity exec \
  -H ${sing_home} \
  -B ${output_folder}:/output_folder \
  ${ciftify_container} wb_command -cifti-convert -to-text \
  /output_folder/${atlas}/ptseries/${sub}/${sub}_${ses}_task-rest_${atlas}_desc-cleanwGSRsm2_bold.ptseries.nii \
  /output_folder/${atlas}/csv/${sub}/${sub}_${ses}_task-rest_${atlas}_desc-cleanwGSRsm2_meants.csv \
  -col-delim ","

done

rm -r ${sing_home}
```

using pure python

```

```py
import nilearn.image
import nibabel as nib

## could set up setting as a dict? for hard code them in this section..


## also add some image loading

## also need to read in the tsv with pandas

## note we might also trim dummy scans here... (i.e. slice out the first three images)

def clean_image_with_nilearn(input_img, confound_signals, settings):
    '''clean the image with nilearn.image.clean()
    '''
    # first determiner if cleaning is required
    if any((settings.detrend == True,
           settings.standardize == True,
           confound_signals is not None,
           settings.high_pass is not None,
           settings.low_pass is not None)):

        # the nilearn cleaning step..
        clean_output = nilearn.image.clean_img(input_img,
                            detrend=settings.detrend,
                            standardize=settings.standardize,
                            confounds=confound_signals.values,
                            low_pass=settings.low_pass,
                            high_pass=settings.high_pass,
                            t_r=settings.func.tr)
        return clean_output
    else:
        return input_img

## then can pass the image to HCP utils for parcellating

```

jerry's notebook for cleaning - https://conp-pcno-training.github.io/neuroimaging-carpentry/
hcp utils (for parcellating) -  https://rmldj.github.io/hcp-utils/

also - my last years code for doing working with ptseries (follows from the containers way..)

https://github.com/krembilneuroinformatics/kcni-school-lessons/blob/master/day5/notebooks/Neuroimaging_Connectomics_01__Images_Surfaces_Atlases.ipynb

https://github.com/krembilneuroinformatics/kcni-school-lessons/blob/master/day5/notebooks/Neuroimaging_Connectomics_03__fMRI_Connectivity.ipynb