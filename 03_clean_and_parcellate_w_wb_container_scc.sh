#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:30:00
#SBATCH --export=ALL
#SBATCH --job-name="cifti_parcellate"
#SBATCH --output=cifti_parcellate_%j.txt

module load tools/Singularity/3.8.5

####----### the next bit only works IF this script is submitted from the $BASEDIR/$OPENNEURO_DS folder...

## set OPENNEURO_DSID to the openneuro dataset id
OPENNEURO_DSID=`basename ${SLURM_SUBMIT_DIR}`

## set the second environment variable to get the base directory
BASEDIR=`dirname ${SLURM_SUBMIT_DIR}`

## use bash to find the location of the currently running script so I can find stuff relative to it
CODEDIR=$(dirname "$0")
echo "$CODEDIR"
config_json=${CODEDIR}/cleaning_settings.json

## note the dlabel file path must be a relative to the output folder
dlabel_file=${BASEDIR}/parcellations/Schaefer2018_100Parcels_7Networks_order.dlabel.nii
atlas="atlas-SchaeferP100N7"

## set up a trap that will clear the ramdisk if it is not cleared
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

#trap the termination signal, and call the function 'trap_term' when
# that happens, so results may be saved.
trap "cleanup_ramdisk" TERM

# input is BIDS_DIR this is where the data downloaded from openneuro went
export BIDS_DIR=${BASEDIR}/${OPENNEURO_DSID}/bids

## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export SING_CONTAINER=${BASEDIR}/containers/fmriprep-20.2.7.simg


## setting up the output folders
export DERIVED_DIR=${BASEDIR}/${OPENNEURO_DSID}/derived/
# export LOCAL_FREESURFER_DIR=${SCRATCH}/${STUDY}/data/derived/freesurfer-6.0.1
export WORK_DIR=${BASEDIR}/${OPENNEURO_DSID}/work/
export LOGS_DIR=${BASEDIR}/${OPENNEURO_DSID}/logs
# mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} ${LOGS_DIR} # ${LOCAL_FREESURFER_DIR}

## get the subject list from a combo of the array id, the participants.tsv and the chunk size
SUB_SIZE=1 ## number of subjects to run
CORES=2
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`
SUBJECT=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`


index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist \
   | tail -n 1
}


sing_home=$(mktemp -d -t wb-XXXXXXXXXX)

fmriprep_folder=${DERIVED_DIR}/fmriprep



# task_dir=$(find ${output}/ciftify/`index`/MNINonLinear/Results/ -type d -name "ses-0*_task-rest*")
cifti_bold=$(find ${fmriprep_folder}/ -type f -name "*_task-*_bold.dtseries.nii")

for ff in ${cifti_bold};
do
if [[ "$ff" == *"$SUBJECT"* ]]; then

func_base=$(basename ${ff})
dtseries=${ff}
echo $func_base

if [[ "$ff" == *"ses"* ]]; then

sub="$(cut -f1 -nd "_" <<< "$func_base")"
ses="$(cut -f2 -nd "_" <<< "$func_base")"
task="$(cut -f3 -nd "_" <<< "$func_base")"
container_dtseries=/fmriprep/${sub}/${ses}/func/${func_base}
cleaned_dtseries=/output/cifti_clean/${sub}/${ses}/func/${sub}_${ses}_${task}_space-fsLR_den-91k_desc-cleaneds0_bold.dtseries.nii
output_ptseries=/output/parcellated/${atlasname}/ptseries/${sub}/${ses}/func/${sub}_${ses}_${task}_atlas-${atlasname}_desc-cleaneds0_bold.ptseries.nii
output_csv=/output/parcellated/${atlasname}/csv/${sub}/${ses}/func/${sub}_${ses}_${task}_atlas-${atlasname}_desc-cleaneds0_meants.csv

mkdir -p ${DERIVED_DIR}/cifti_clean/${sub}/${ses}
mkdir -p ${DERIVED_DIR}/parcellated/${atlasname}/ptseries/${sub}/${ses}
mkdir -p ${DERIVED_DIR}/parcellated/${atlasname}/csv/${sub}/${ses}

else

sub="$(cut -f1 -nd "_" <<< "$func_base")"
task="$(cut -f2 -nd "_" <<< "$func_base")"
container_dtseries=/fmriprep/${sub}/func/${func_base}
confounds_tsv=/fmriprep/${sub}/func/${sub}_${task}_desc-confounds_timeseries.tsv
cleaned_dtseries=cifti_clean/${sub}/func/${sub}_${task}_space-fsLR_den-91k_desc-cleaneds0_bold.dtseries.nii
output_ptseries=parcellated/${atlasname}/ptseries/${sub}/func/${sub}_${task}_atlas-${atlasname}_desc-cleaneds0_bold.ptseries.nii
output_csv=parcellated/${atlasname}/csv/${sub}/func/${sub}_${task}_atlas-${atlasname}_desc-cleaneds0_meants.csv

mkdir -p ${DERIVED_DIR}/cifti_clean/${sub}/${ses}
mkdir -p ${DERIVED_DIR}/parcellated/${atlasname}/ptseries/${sub}/${ses}
mkdir -p ${DERIVED_DIR}/parcellated/${atlasname}/csv/${sub}/${ses}

fi

echo $dtseries
echo $container_dtseries

fi
done

mkdir -p ${output_folder}/${atlas}/ptseries/${sub}
mkdir -p ${output_folder}/${atlas}/csv/${sub}

singularity exec \
-H ${sing_home} \
-B ${DERIVED_DIR}:/output \
-B ${fmriprep_folder}:/fmriprep \
-B ${clean_config} \
${ciftify_container} ciftify_clean_img \
    --output-file=${cleaned_dtseries}\
    --clean-config=${clean_config} \
    --confounds-tsv=${confounds_tsv}\
    /output/{container_dtseries}

singularity exec \
-H ${sing_home} \
-B ${DERIVED_DIR}:/output \
-B ${dlabel_file} \
${ciftify_container} wb_command -cifti-parcellate \
 /output/${cleaned_dtseries} \
  ${dlabel_file} \
  COLUMN \
  /output/${output_ptseries} \
  -include-empty

singularity exec \
  -H ${sing_home} \
  -B ${DERIVED_DIR}:/output \
  ${ciftify_container} wb_command -cifti-convert -to-text \
  /output/${output_ptseries} \
  /output/${output_csv} \
  -col-delim ","

done

rm -r ${sing_home}