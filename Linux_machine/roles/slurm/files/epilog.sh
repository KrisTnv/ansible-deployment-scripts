#epilog
#!/bin/bash

#epilog file is suited for workshop cluster with NO GPU in the cluster

# SLURM eplilog
# Executed by the root user when a users job finishes
# Clean tmp directores, kill remaining jobs and clean cache
# epilogue gets 9 arguments:
# 1 -- jobid SLURM_JOB_ID
# 2 -- userid SLURM_JOB_USER
# 3 -- grpid
# 4 -- job name
# 5 -- sessionid
# 6 -- resource limits
# 7 -- resources used
# 8 -- queue
# 9 -- account SLURM_JOB_ACCOUNT
#

## Get the current hostname
s_hostname=$(hostname)

## Set the nodes to filter out
#s_login_array=(tursa-login1,tursa-login2,tursa-login3,tursa-login4)


## Check our hostname against the login node array
#if [[ "${s_login_array[@]}" =~ "${s_hostname}" ]]; then
#        # Nothing to do on a login node so just exit
#        exit 0
#fi

##
## Kill and procs left running on a GPU
## Slurm must create the /tmp/GPU${SLURM_JOB_ID}.txt file as part of prolog!
##

list_descendants ()
{
  local children=$(ps -o pid= --ppid "$1")

  for pid in $children
  do
    list_descendants "$pid"
  done
  echo "$children"
}

if [ -f /tmp/GPU${SLURM_JOB_ID}.txt ] ; then
   GPULIST=`cat /tmp/GPU${SLURM_JOB_ID}.txt | sed 's/,/ /g'`
   for f in $GPULIST
   do
      gpupid=`nvidia-smi pmon -c 1 -i $f | tail -1 | awk '{print $2}'`
      #echo GPU $f has PID: $gpupid
      if [ ! -z "$gpupid" ] ; then
         # had issues on Jade1 where memory wasn't being cleared
         # therefore attempting a sigterm before resorting to sigkill.
         kill -15 $(list_descendants $gpupid) &
         sleep 5
         kill -15 $gpupid &
         sleep 5
         kill -9 $(list_descendants $gpupid)
         sleep 1
         kill -9 $gpupid
      fi
   done
   rm -f /tmp/GPU${SLURM_JOB_ID}.txt
   rm -rf /tmp/*
fi
# Ensure it is down
sleep 10

##
## Grab job information
##
runtime=$(scontrol   show job=$SLURM_JOB_ID | grep RunTime   | awk '{print $1}' | cut -d= -f 2 )
numnodes=$(scontrol  show job=$SLURM_JOB_ID | grep NumNodes  | awk '{print $1}' | cut -d= -f 2 )
jobstate=$(sacct --noheader  --jobs=$SLURM_JOB_ID --format=state | tail -1)
jobstart=$(sacct --noheader  --jobs=$SLURM_JOB_ID --format=start | tail -1)
jobend=$(sacct --noheader  --jobs=$SLURM_JOB_ID --format=end | tail -1)
partition=$(scontrol show job=$SLURM_JOB_ID | grep Partition | awk '{print $1}' | cut -d= -f 2 )
date=$(date "+%D %R")

echo $SLURM_JOB_ID,$jobstate$numnodes,$partition,$SLURM_JOB_ACCOUNT,$SLURM_JOB_USER,$runtime,$jobstart,$jobend >> /var/spool/SLURM/jobsummary.txt


#We do not have GPU in the workshop cluster to commenting the below
# Reset GPUs to clear memory remapper error states
#systemctl stop nvidia-persistenced
#systemctl stop dcgm-exporter
#systemctl stop dcgm
#nvidia-smi -r
#systemctl start dcgm
#systemctl start dcgm-exporter
#systemctl start nvidia-persistenced

##
## resets nvidia mode, in case it gets changed
## Issue seen on other clysters
##
#/usr/bin/nvidia-smi --compute-mode=0

exit 0
