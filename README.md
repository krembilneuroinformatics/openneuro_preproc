# openneuro_preproc
A group of workflows for using openneuro data

testing if I can edit from scinet

Steps required

## Download the data (hopefully with datalad)

Destination - because we are trying to make this a general purpose repo - we will avoid the nesting as a subdataset bit I usually like so much?

if in the terminal - load the datalad module

Set these two environment variables to get everything going

```sh
## set OPENNEURO_DSID to the openneuro dataset id
OPENNEURO_DSID="ds000030"

## set the second environment variable to get the base directory
BASEDIR=$SCRATCH/openneuro_datasets
```

## cloning this repo into the home folder

To get started let's make sure we have this scripts in the code folder

```sh

```

## The final structure

```


```

```sh
## loading Erin's datalad environment on the SciNet system
module load git-annex/8.20200618 # git annex is needed by datalad
module use /project/a/arisvoin/edickie/modules #this let's you read modules from Erin's folder
module load datalad/0.15.5 # this is the datalad module in Erin's folder


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

### submitting the fmriprep_anat step

```sh
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
sbatch --array=0-${array_job_length} ${BASEDIR}/${OPENNEURO_DSID}/code/01_fmriprep_anat_scinet.sh
```


## cleaning?  - hopefully w cifti clean - but there are options


## parcellating data - with Shaefer


## QCing everything that has been done