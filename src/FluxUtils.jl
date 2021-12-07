module FluxUtils

using FluxRM

function __get_treedict!(dict, path...)
    next_dict = dict
    for node in path
        next_dict = get!(()-> Dict{String, Any}(), next_dict, node)
    end
    return next_dict
end

function __set_io_path(spec::FluxRM.JobSpec.Jobspec, iotype, name, path)
    system = spec.attributes.system
    if system.shell === nothing
        system.shell = Dict{String, Any}()
    end
    io = __get_treedict!(system.shell, "options", iotype, name)

    io["type"] = "file"
    io["path"] = path
end


function propagate_load_path!(env, project=Base.ACTIVE_PROJECT[])
    pathsep = Sys.iswindows() ? ";" : ":"
    if get(env, "JULIA_LOAD_PATH", nothing) === nothing
        env["JULIA_LOAD_PATH"] = join(LOAD_PATH, pathsep)
    end
    if get(env, "JULIA_DEPOT_PATH", nothing) === nothing
        env["JULIA_DEPOT_PATH"] = join(DEPOT_PATH, pathsep)
    end
    # Set the active project on workers using JULIA_PROJECT.
    # Users can opt-out of this by (i) passing `env = ...` or (ii) passing
    # `--project=...` as `exeflags` to addprocs(...).
    if project !== nothing && get(env, "JULIA_PROJECT", nothing) === nothing
        env["JULIA_PROJECT"] = project
    end
end


function juliaspec(args, dir; num_nodes=1, num_tasks_per_node=1, cores_per_task=4, project=dir)
    num_tasks = num_nodes*num_tasks_per_node
    cmd = `$(Base.julia_cmd()) $(args)`
    jobspec = FluxRM.JobSpec.from_command(cmd; num_nodes, num_tasks, cores_per_task)
    system = jobspec.attributes.system
    system.cwd = realpath(dir)
    env = Dict{String, String}()
    propagate_load_path!(env, realpath(project))
    system.environment = env
    __set_io_path(jobspec, "output", "stderr", "flux-{{id}}.err")
    __set_io_path(jobspec, "output", "stdout", "flux-{{id}}.out")
    @assert FluxRM.JobSpec.validate(jobspec, 1)
    jobspec
end

function nodes()
    rpc = fetch(FluxRM.RPC(Flux(), "resource.status", nodeid=0))
    R = first(rpc.R.execution.R_lite)

    hosts = FluxRM.IDSet(R.rank) 
    Int(length(hosts))
end

struct Job
    workdir::String
    preload::String
    cmd::String
end

function Base.run(job::Job)
    args = String[]
    if job.preload != ""
        append!(args, ["-L", job.preload])
    end
    append!(args, ["-e", job.cmd])

    jobspec = juliaspec(args, job.workdir)
    submission = FluxRM.submit(Flux(), jobspec)
    return FluxRM.Job(submission)
end

end # module
