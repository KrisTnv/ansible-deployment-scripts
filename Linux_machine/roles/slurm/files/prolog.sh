## I think we can skip most of the parts as we are not using it
## Keeping the file 


#prolog.sh
#!/bin/bash
# Run these scripts before the job runs - as the user running the job
# If the script needs root access, make sure you add it to sudo

# EXIT CODES
# 0 - OK
# 1 - General Error
# 5 - Failed to create files in /tmp
# 6 - Failed to remove files in /tmp
# 7 - Failed to create file in HOME
# 8 - Failed to remove files from HOME
# 9 - Failed to obtain SLURM user
# 10 - Failed to obtain SLURM job ID


### DEBUG
#echo "+-+" > /tmp/slurm_env
#hostname >> /tmp/slurm_env
#echo "user: ${SLURM_JOB_USER}" >> /tmp/slurm_env
#env >> /tmp/slurm_env
#echo "-+-" >> /tmp/slurm_env


##
## This script is shared between the compute and login
## and is called on BOTH the compute and login
## so filter out some of the actions for the login nodes
##

## Get the current hostname
s_hostname=$(hostname)

## Set the nodes to filter out
s_login_array=(tursa-login1,tursa-login2,tursa-login3,tursa-login4)

## Check our hostname against the login node array
if [[ "${s_login_array[@]}" =~ "${s_hostname}" ]]; then
       	# Nothing to do on a login node so just exit
        exit 0
fi

##
## Add the user's group to huge pages
##

echo "$SLURM_JOB_GID"  > /proc/sys/vm/hugetlb_shm_group

##
## Create temp file of the slurm job ID
## used for epilogue cleanup
##
echo $NV_GPU > /tmp/GPU${SLURM_JOB_ID}.txt
if [ ! -f /tmp/GPU${SLURM_JOB_ID}.txt ] ; then
  echo $CUDA_VISIBLE_DEVICES > /tmp/GPU${SLURM_JOB_ID}.txt
fi

##
## Run checks to ensure host is healthy. Checks /tmp and $HOME
##
touch /tmp/$$.tmp
if [ $? -ne 0 ] ; then
        echo "Unable to create file in /tmp/ on $HOSTNAME"   ; exit 5
fi
rm -f /tmp/$$.tmp
if [ $? -ne 0 ] ; then
        echo "Unable to remove file from /tmp/ on $HOSTNAME" ; exit 6
fi

touch $HOME/$$.tmp
if [ $? -ne 0 ] ; then
        echo "Unable to create file in $HOME on $HOSTNAME"   ; exit 7
fi

rm -f $HOME/$$.tmp
if [ $? -ne 0 ] ; then
        echo "Unable to remove file from $HOME on $HOST"     ; exit 8
fi

