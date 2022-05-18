# Erin's notes on building python virtual envs

Building or referencing virtual envs on the SCC or SciNet. And connecting them to the jupyterhub environment.

So
# On SciNet

Also need git-annex (kimel version is 8.2 something..)

module load git-annex/8.20200618

This is the 
```sh
# This is a python virtualenv
# This module can be reconstructed in the following way
module load python/3.9.8
module load git-annex/8.20200618 

mkdir -vp /project/a/arisvoin/edickie/modules/datalad/0.15.5/{build,src}
cat $0 > /project/a/arisvoin/edickie/modules/datalad/0.15.5/src/README.sh
cat requirements.txt > /project/a/arisvoin/edickie/modules/datalad/0.15.5/src/requirements.txt
virtualenv --prompt 'datalad' --activators bash,python /project/a/arisvoin/edickie/modules/datalad/0.15.5/build
source /project/a/arisvoin/edickie/modules/datalad/0.15.5/build/bin/activate
pip list --outdated | awk 'BEGIN {ORS = "\0"}
                           $2 ~ /[[:digit:]]/ {print $1}' \
                    | xargs -0 pip install --upgrade
pip install -r requirements.txt
pip install ipykernel
```

content of  requirements.txt 

```
datalad==0.15.5
datalad-container==1.1.5
datalad-crawler==0.9.3
datalad-deprecated==0.1
datalad-fuse==0.2.0
datalad-hirni==0.0.8
datalad-metadata-model==0.2.0rc2
datalad-metalad==0.2.1
datalad-mihextras==0.6.0
datalad-neuroimaging==0.3.1
datalad-ukbiobank==0.3.3
datalad-webapp==0.3
datalad-xnat==0.2
git-annex-remote-globus==1.2.3
```

contents of module file

```
help( [[ Adds DataLad 0.15.5 (as a virtualenv) to your environment ]] )

conflict("python")

local ac = [[ source /project/a/arisvoin/edickie/modules/datalad/0.15.5/build/bin/activate ]]
local deac = [[ "deactivate" ]]

pushenv("LC_ALL", "en_US.UTF-8")
pushenv("LC_CTYPE", "en_US.UTF-8")

execute{cmd=ac,modeA={"load"}}
execute{cmd=deac,modeA={"unload"}}
```

For my own use - I would like this to work within the jupyterhub

```
python -m ipykernel install --prefix=/project/a/arisvoin/edickie/modules/datalad/0.15.5/build --name 'datalad' --display-name "Python (datalad)"

```

 - so that kinda worked? although the name of the kernel is now "build" which is not that nice?

how to load this module in a terminal

```
module load git-annex/8.20200618
module use /project/a/arisvoin/edickie/modules
module load datalad/0.15.5
```

# on the scc

git-annex version is 8.20200618

getting a base python env

```sh
module load PYTHON/3.8.5-Anaconda3-2021.03
```

getting the kimel modules - note this only gets the ones that Dawn wrote for the SCC - not all of them

```sh
source /KIMEL/tigrlab/quarantine/scc_modules.sh
```

