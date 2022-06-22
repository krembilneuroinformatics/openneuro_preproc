# openneuro_preproc
A group of workflows for using openneuro data

testing if I can edit from scinet

Steps required:

 - Before you start - [set these environment variables](#before-you-start---all-code-in-this-workflow-uses-two-environment-variables)
   - [clone this repo](#cloning-this-repo-into-the-home-folder)
   - [this is what the output will look like](#the-final-structure-this-repo-is-coded-to-work-with)
 - Downloading data
   - [loading datalad env on scinet](#loading-datalad-on-scinet-niagara)
   - [loading datalad env on scc](#loading-a-datalad-env-on-the-scc)
   - [Downloading Data with datalad](#using-datalad-to-install-a-download-a-dataset)
- Running fMRIprep
  - [setting up fMRIprep container and env](#)
  -

## Before you start - all code in this workflow uses two environment variables

Destination - because we are trying to make this a general purpose repo - we will avoid the nesting as a subdataset bit I usually like so much?

if in the terminal - load the datalad module

Set these two environment variables to get everything going

```sh
## set OPENNEURO_DSID to the openneuro dataset id
OPENNEURO_DSID="ds000030"

## set the second environment variable to get the base directory
BASEDIR=$SCRATCH/openneuro_datasets
```

This is where data is sitting on the scc

```sh
BASEDIR=/external/rprshnas01/external_data/openneuro
```

### cloning this repo into the home folder

To get started let's make sure we have this scripts in the code folder

```sh
mkdir ${BASEDIR}/code
cd ${BASEDIR}/code
git clone git@github.com:krembilneuroinformatics/openneuro_preproc.git
```

Note: for this to work - you need to add a ssh key for SciNet to your github.
 - [instructions here for creating the key]()

### The final structure this repo is coded to work with

```
${BASEDIR}
├── code
│   └── openneuro_preproc        # a clone of this repo
├── containers
│   └── fmriprep-20.2.7.simg     # the singularity image used to run fmriprep
├── ${OPENNEURO_DSID}            # folder for the dataset
│   ├── bids                     # the bids data is the data downloaded from openneuro
│   ├── derived                  # holds derivatives derived from the bids data
│   └── logs                     # logs from jobs run on cluster
└── fmriprep_home                # an extra folder with pre-downloaded fmriprep templates (see setup section)

```

## loading a datalad env on the scc

```sh
## git annex is already on all nodes
source /external/rprshnas01/netdata_kcni/edlab/venvs/datalad-0-15-5/bin/activate
```

## loading datalad on SciNet niagara
```sh
## loading Erin's datalad environment on the SciNet system
module load git-annex/8.20200618 # git annex is needed by datalad
module use /project/a/arisvoin/edickie/modules #this let's you read modules from Erin's folder
module load datalad/0.15.5 # this is the datalad module in Erin's folder
```

## using datalad to install a download a dataset

```
mkdir -p ${BASEDIR}/${OPENNEURO_DSID}/
cd ${BASEDIR}/${OPENNEURO_DSID}/
datalad clone https://github.com/OpenNeuroDatasets/${OPENNEURO_DSID}.git bids
```

The above bit would "clone" the dataset - meaning it will only download the little files and download instructions. To actually download the imaging data we need to use "datalad get".

This is useful - because we can limit downloading time/space by exploring the dataset and only downloading what we are really interested in.

Let's start by getting all the anatomical MRI images - we always need these

```sh
cd ${BASEDIR}/${OPENNEURO_DSID}/bids
datalad get */anat/*
```

next - let's grab the resting-state fMRI data and associated files. Under BIDS convension - they are always in the "func" folder and all have "task-rest" in their filename.

```sh
cd ${BASEDIR}/${OPENNEURO_DSID}/bids
datalad get */anat/*task-rest*
```

## Running fmriprep

## setting up the fmriprep environment

building fmriprep container on scinet

This step was run by Erin


```sh
module load singularity/3.8.0
# singularity build /my_images/fmriprep-<version>.simg docker://nipreps/fmriprep:<version>
mkdir ${BASEDIR}/containers
singularity build ${BASEDIR}/containers/fmriprep-20.2.7.simg \
                    docker://nipreps/fmriprep:20.2.7
```

Testing and setting up for the singularity run..

we need a copy of the freesurfer license to be in:

```sh
ls ${BASEDIR}/fmriprep_home/.freesurfer.txt
```
Testing the singularity binds..

```sh
cd $BASEDIR

singularity shell --cleanenv \
    -B ${BASEDIR}/fmriprep_home:/home/fmriprep --home /home/fmriprep \
    containers/fmriprep-20.2.7.simg
```

From inside the container - set up templateflow (note due this before submitting a job)

```
python -c "from templateflow.api import get; get(['MNI152NLin2009cAsym', 'MNI152NLin6Asym'])"
python -c "from templateflow.api import get; get(['fsaverage', 'fsLR'])"
python -c "from templateflow.api import get; get(['OASIS30ANTs'])"
```

### submitting the fmriprep_anat step (scinet)

Note: this step uses and estimated **24hrs for processing time** per participant! So if all participants run at once (in our parallel cluster) it will still take a day to run.

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## don't forget to make sure that $BASEDIR and $OPENNEURO_DSID are defined..

module load singularity/3.8.0
## go to the repo and pull new changes
cd ${BASEDIR}/code/openneuro_preproc
git pull

## calculate the length of the array-job given
SUB_SIZE=5
N_SUBJECTS=$(( $( wc -l ${BASEDIR}/${OPENNEURO_DSID}/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
cd ${BASEDIR}/${OPENNEURO_DSID}
sbatch --array=0-${array_job_length} ${BASEDIR}/code/openneuro_preproc/code/01_fmriprep_anat_scinet.sh
```
### submitting the fmriprep func step (scinet)

Running the functional step looks pretty similar to running the anat step. The time taken and resources needed will depend on how many functional tasks exists in the experiment - fMRIprep will try to run these in paralell if resources are available to do that.

Note -  the script enclosed uses some interesting extra opions:
 - it defaults to running all the fmri tasks - the `--task-id` flag can be used to filter from there
 - it is outputing cifti files (HCP fsLR91k space as well as MNI and native space outputs)
 - it is running `synthetic distortion` correction by default - instead of trying to work with the datasets available feildmaps - because feildmaps correction can go wrong.

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## don't forget to make sure that $BASEDIR and $OPENNEURO_DSID are defined..

module load singularity/3.8.0
## go to the repo and pull new changes
cd ${BASEDIR}/code/openneuro_preproc
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ${BASEDIR}/${OPENNEURO_DSID}/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
cd ${BASEDIR}/${OPENNEURO_DSID}
sbatch --array=0-${array_job_length} ${BASEDIR}/code/openneuro_preproc/code/02_fmriprep_func_scinet.sh
```

### running fmriprep on the scc

**Before running this make sure that the fmriprep container exits and that you have set the freesurfer license** [instructions above](#setting-up-the-fmriprep-environment)

Also don't forget about setting the environment variables for `$BASEDIR` and `$OPENNEURO_DSID`

```sh
## note step one is to make sure you are on one of the submit nodes
ssh dev02

## don't forget to make sure that $BASEDIR and $OPENNEURO_DSID are defined..

## go to the repo and pull new changes
cd ${BASEDIR}/code/openneuro_preproc
git pull

## figuring out appropriate array-job size
N_SUBJECTS=$(( $( wc -l ${BASEDIR}/${OPENNEURO_DSID}/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
echo "number of array is: ${N_SUBJECTS}"

## submit the array job to the queue
cd ${BASEDIR}/${OPENNEURO_DSID}
sbatch --array=0-${array_job_length} ${BASEDIR}/code/openneuro_preproc/code/01_fmriprep_func_scc.sh
```

## cleaning and parcellating - hpc script based

We added a script to use the a singularity container to run `ciftify_clean_img` to run confound regression on the images and `wb_command -cifti-parcellate` to parcellate the timeseries into the Schaefer 100 parcels (7 network) parcellation.

To run the script on the SCC

```sh
## note step one is to make sure you are on one of the submit nodes
ssh dev02

module load tools/Singularity/3.8.5

## don't forget to make sure that $BASEDIR and $OPENNEURO_DSID are defined..
echo "the basedir is ${BASEDIR}"
echo "the dataset is ${OPENNEURO_DSID}"

## go to the repo and pull new changes
cd ${BASEDIR}/code/openneuro_preproc
git pull

## figuring out appropriate array-job size
N_SUBJECTS=$(( $( wc -l ${BASEDIR}/${OPENNEURO_DSID}/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
echo "number of array is: ${N_SUBJECTS}"

## submit the array job to the queue
cd ${BASEDIR}/${OPENNEURO_DSID}
mkdir -p logs

sbatch --array=0-${N_SUBJECTS} ${BASEDIR}/code/openneuro_preproc/code/03_clean_and_parcellate_w_wb_container_scc.sh
```
Note: just for ds000201 - which was run with an older version of fmriprep - I needed to use `03_clean_and_parcellate_w_wb_container_scc_r.sh` spot the difference!

## QCing everything that has been done

### python code for viewing a bunch o images in a notebook

```py
from IPython.display import Image
from glob import glob

image_list  =  glob('star/path/to/images')
image_list.sort()

for this_image in image_list:
    print('/n')
    print(this_image)
    display(Image(filename=this_image))
```

copying all the fmriprep QA images into one subdirectory

```sh
QA_dir=${BASEDIR}/${OPENNEURO_DSID}/derived/fmriprep_QA_only
FMRIPREP_dir=${BASEDIR}/${OPENNEURO_DSID}/derived/fmriprep

mkdir -p ${QA_dir}

subjects=`cd ${FMRIPREP_dir}; ls -1d sub-* | grep -v html`

cp ${FMRIPREP_dir}/*html ${QA_dir}/
for subject in ${subjects}; do
 mkdir -p ${QA_dir}/${subject}/figures
 rsync -av ${FMRIPREP_dir}/${subject}/figures ${QA_dir}/${subject}/figures
done
```



## Running dwi preprocessing

Before running the script please run the FreeSurfer cortical reconstruction process

```sh
export FREESURFER_HOME=/Applications/freesurfer
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=put/your/path/here
## An example of running a subject through Freesurfer with a T2 image:
recon-all -subject subjectname -i /path/to/input_volume -T2 /path/to/T2_volume -T2pial -all
```

Please note that if you have already run FMRIPREP, you will have the FreeSurfer cortical reconstruction as part of the output


Once you have FreeSurfer cortical reconstruction folders ready, first you are going to create the atlas and register that with dwi b0.
For doing that first create a parcel2use.txt file with the parcellation that you would like to use.

```sh
echo 'Schaefer2018_100Parcels_7Networks_order.annot' > parcel2use.txt
```

Then, using a similar command, please create a list with the subjects' folder name that you are going to preprocessing.
There are different way for doing that. One possibility is nagivating to the FreeSurfer subjects' folder and typing the following command:

```sh
ls > subjList.txt
```

 A second possibility is run the following script:

```sh
 if [ ! -f subjList.txt ]; then
 ls | grep ^sub- > subjList.txt
 fi
```

Once these two .txt file has been created, you are ready for running the first dwi preprocessing.

Specifically for creating the atlas please run:

```sh
04_dwi_creating_atlas
```

Once the atlas has been created please run the dwi preprocessing:

```sh
05_dwi_preproc
```
