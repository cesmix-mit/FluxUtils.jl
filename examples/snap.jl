using FluxRM
using FluxUtils

using FluxRM
const flux = Flux()

const kvs = FluxRM.KVS(flux)
FluxRM.transaction(kvs) do txn
    FluxRM.mkdir!(txn, "run_snap")
end

const __job_counter = Ref{Int64}(0)
function job_counter()
    counter = __job_counter[]
    __job_counter[] = counter + 1
    counter
end

function md_job(params)
    counter = job_counter()

    path = "run_snap.job_$counter"

    FluxRM.transaction(kvs) do txn
        FluxRM.mkdir!(txn, path)
        put_raw!(txn, path * ".input", Dict(:data => params))
    end

    script = """
    const kvs = FluxRM.KVS(Flux())
    input = FluxRM.lookup(kvs, $path * ".input")
    params = input[:data]

    out = run_md(params)

    FluxRM.transaction(kvs) do txn
        put_raw!(txn, $path * ".output", Dict(:data => out))
    end
    """

    return FluxUtils.Job(".", "utils.jl", script)
end

tasks = []
for (i, β) in enumerate(β_samples)
    md_params = MDParams(
        vcat([βi for βi in β]...),
        params, starting_file, save_dir*"$(i)/", Tend,
        dt, i, Temp, dT) 
    
    job = md_job(md_params)
    push!(tasks, run(job))
end

# forall(tasks) do task
#     # wait(task)
#     if success(task)
#         out = fetch(tasks)
#         #  something productive here
#     else
#         @warn "task failed" task
#     end
# end


# function get_params!(server)
# end

# function update_params!(server, gradient)
# end

# for iter in interations
#     params = get_params!(server)
#     gradient = Zygote.get_gradients(run_md, params)
#     update_params!(server, gradient)
# end