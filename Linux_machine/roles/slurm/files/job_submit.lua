#!/usr/bin/lua
--
-- Slurm job submit for ARCHER2
--
-- Copyright: (C) 2020-2021 EPCC
--
-- Contact: Iakovos Panourgias (i.panourgias@epcc.ed.ac.uk)
--          Steven Robson (s.robson@epcc.ed.ac.uk)
--
-- This program is free software; you can redistribute in and/or modify
-- it under the terms of the GNU General Public License, version 2, as
-- published by the Free Software Foundation.  This program is
-- distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
-- for more details.  On Calibre systems, the complete text of the GNU
-- General Public License can be found in
-- `/usr/share/common-licenses/GPL'.
--
--

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end


function slurm_job_submit ( job_desc, part_list, submit_uid )
    username                 = job_desc.user_name
    time_limit               = job_desc.time_limit       -- equal to "--time="
    name                     = job_desc.name
    shared                   = job_desc.shared
    min_nodes                = job_desc.min_nodes        -- equal to "--nodes"
    num_tasks                = job_desc.num_tasks        -- equal to "--ntasks="
    ntasks_per_node          = job_desc.ntasks_per_node  -- equal to "--ntasks-per-node="
    min_mem_per_node         = job_desc.min_mem_per_node -- equal to "--mem="
    min_mem_per_cpu          = job_desc.min_mem_per_cpu  -- equal to "--mem-per-cpu="
    tres_per_node            = job_desc.tres_per_node    -- equal to "--gres=gpu:X"
    req_nodes                = job_desc.req_nodes        -- equal to "-w nodelist"
    exc_nodes                = job_desc.exc_nodes        -- equal to " -x, --exclude=<node name list>"
    partition                = job_desc.partition
    reservation_name         = job_desc.reservation
    qos                      = job_desc.qos
    work_dir                 = job_desc.work_dir
    user_account             = job_desc.account
    default_account          = job_desc.default_account
    switches                 = job_desc.req_switch
    features                 = job_desc.features
    num_gpus_num             = 0
    num_gpus_text            = "none"
    user_spec_nodes          = 0
    user_spec_tasks          = 0
    user_spec_tasks_per_node = 0

    -- standardlength=2880

    slurm.log_info("tursa_job_submit: Job submission evaluation START for %s", username)

    if tres_per_node ~= nil then
        num_gpus_text=string.match(tres_per_node, ":(.*)")
        num_gpus_num=tonumber(num_gpus_text)
        slurm.log_info("tursa_job_submit: GPUs %u", num_gpus_num)
    else
        num_gpus_num = 0
    end

    if shared ~= 0 then
        slurm.log_info("tursa_job_submit: Shared Job")
    elseif shared == 0 then
        slurm.log_info("tursa_job_submit: Exclusive Job")
    end


    if min_mem_per_node == nil then
        slurm.log_info("tursa_job_submit: min_mem_per_node was nil")
    end

    if min_mem_per_cpu == nil then
        slurm.log_info("tursa_job_submit: min_mem_per_cpu was nil")
    end

    if min_nodes == nil then
        slurm.log_info("tursa_job_submit: min_nodes was nil")
    elseif min_nodes == 4294967294 then
        slurm.log_info("tursa_job_submit: min_nodes was 4294967294")
    elseif min_nodes == 1 then
        slurm.log_info("tursa_job_submit: min_nodes was 1")
    else
        user_spec_nodes = 1
        slurm.log_info("tursa_job_submit: user specified min_nodes was %s", min_nodes)
    end

    if ntasks_per_node == nil then
        slurm.log_info("tursa_job_submit: ntasks_per_node was nil")
    else
        user_spec_tasks_per_node = 1
    end


    if num_tasks == nil then
        slurm.log_info("tursa_job_submit: num_tasks was nil")
    elseif num_tasks > 42949672 then
        slurm.log_info("tursa_job_submit: num_tasks was not provided")
    else
        user_spec_tasks = 1
    end


    -- Account checking - Log default and specified budget account
    if default_account ~= nil then
        slurm.log_info("tursa_job_submit: default account is %s", default_account)
    else
        slurm.log_info("tursa_job_submit: no default account")
    end

    if user_account ~= nil then
        slurm.log_info("tursa_job_submit: account provided %s", user_account)
    else
        slurm.log_info("tursa_job_submit: no account provided")
    end

    if features ~= nil then
        slurm.log_info("tursa_job_submit: Features supplied is %s", features)
    else
        slurm.log_info("tursa_job_submit: no features requested")
    end

    -- If ask for specific nodes or to exclude nodes, then reject
    if req_nodes ~= nil then
        slurm.log_info("tursa_job_submit: Specific nodes requested. Reject job")
        slurm.log_user("Job rejected: Please do not request specific nodes.")
        return slurm.ERROR
    elseif exc_nodes ~= nil then
        slurm.log_info("tursa_job_submit: Specific nodes excluded. Reject job")
        slurm.log_user("Job rejected: Please do not request to exclude specific nodes.")
	return slurm.ERROR
    end

    -- Partition tests - Ensure that standard/largemem jobs are exclusive and that others request nodes appropriately
    if partition ~= nil then
        slurm.log_info("tursa_job_submit: partition specified %s",partition)
        if string.find(partition, "gpu") or string.find(partition, "cpu") then
            -- set job to exclusive for standard and highmem partitions
            slurm.log_info("tursa_job_submit: setting job to exclusive for gpu or cpu")
            job_desc.shared = 0
        elseif shared ~= 0 and user_spec_nodes == 1 then
            --  if ask for nodes in serial and not ask --exclusive, then reject.
            slurm.log_info("tursa_job_submit: nodes specified and not exclusive. Reject job")
            slurm.log_user("Job rejected: Nodes specified but the --exclusive flag is not specifed. Please use the --exclusive flag if you need to specify nodes, or specify tasks or cpus(cores) if not.")
            return slurm.ERROR
        end
    else
        -- Reject jobs that don't specify a partition
        slurm.log_info("tursa_job_submit: partition not specified")
        slurm.log_user("Job rejected: Please specify a partition name.")
        return slurm.ERROR
    end

    -- QoS and time limit tests
    if qos ~= nil then
	if string.find(qos, "maintenance") then
	    slurm.log_info("tursa_job_submit: maintenance qos specified %s",qos)
	else
            slurm.log_info("tursa_job_submit: qos specified %s",qos)
	    if reservation_name ~= nil then
	        if string.find(qos, "reservation") then
                    slurm.log_info("tursa_job_submit: reservation qos requested with reservation. Continue")
                else
                    slurm.log_info("tursa_job_submit: non-reservation qos requested with reservation. Reject job")
                    slurm.log_user("Job rejected: A reservation cannot be used without the reservation QoS. Please use the reservation QoS.")
                    return slurm.ERROR
		end
	    end
	    -- Calculate switches to use based on nodes requested
	    -- Nodes must be powers of 2
     	    if min_nodes == 1 or min_nodes == 2 or min_nodes == 4 or min_nodes == 8 then
		-- Set switches to 1
		calc_switches = 1
		job_desc.req_switch = calc_switches
		slurm.log_info("tursa_job_submit: nodes requested is %s so switches is calculated to be %s",min_nodes,calc_switches)
	    elseif min_nodes == 16 or min_nodes == 32 or min_nodes == 64 or min_nodes == 128 or min_nodes == 256 or min_nodes == 512 or min_nodes == 1024 or min_nodes == 2048 then
		calc_switches = min_nodes // 8
		job_desc.req_switch = calc_switches
		slurm.log_info("tursa_job_submit: nodes requested is %s so switches is calculated to be %s",min_nodes,calc_switches)
	    else
                slurm.log_info("tursa_job_submit: min_nodes %s is not a power of 2. Reject job.", min_nodes)
                slurm.log_user("Job rejected: Please request a node count that is a power of 2.")
                return slurm.ERROR
	    end
	    if min_nodes == 16 then
		slurm.log_info("tursa_job_submit: settings grid16 features")
	        job_desc.features = "[grid16-01|grid16-02|grid16-03|grid16-04|grid16-05|grid16-06|grid16-07]"
	    end
	    if min_nodes == 32 then
                slurm.log_info("tursa_job_submit: settings grid32 features")
                job_desc.features = "[grid32-01|grid32-02|grid32-03]"
            end
	    if min_nodes == 64 then
                slurm.log_info("tursa_job_submit: settings grid64 features")
                job_desc.features = "[grid64-01|grid64-02]"
            end
	end
    else
	slurm.log_info("tursa_job_submit: No qos specified. Reject job")
	slurm.log_user("Job rejected: Please specify a QoS when submitting jobs")
    end

    --  If no time specified, then present warning message to user.
    if time_limit == nil or time_limit == 4294967294 then
        slurm.log_info("tursa_job_submit: No time limit specified")
        slurm.log_user("Warning: Your job has no time specification (--time=) and the default time is short. You can cancel your job with 'scancel <JOB_ID>' if you wish to resubmit.")
    end

    -- Job has passed all tests. Log submission details and END, return successful to Slurm so it will continue to try and schedule the job.
    slurm.log_info("tursa_job_submit: user %s, submitted a job %s",
                username, name)

    slurm.log_info("tursa_job_submit: Job submission evaluation END for %s", username)
    return slurm.SUCCESS
end

function slurm_job_modify ( job_desc, job_rec, part_list, modify_uid )
    slurm.log_info("tursa_job_submit: slurm_job_modify")

    return slurm.SUCCESS
end

slurm.log_info("initialized")

return slurm.SUCCESS

