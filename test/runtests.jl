using Test
using FluxRM

if !haskey(ENV, "FLUX_URI")
    flux_available = try
        success(`flux env`)
    catch
        false
    end

    if !flux_available
        @error "flux-core is not installed, skipping further tests"
        exit()
    end

    @info "relaunching under Flux"
    current_file = @__FILE__ # bug in 1.5 can't be directly interpolated
    jlcmd = `$(Base.julia_cmd()) $(current_file)`
    cmd = `flux start -o,-Slog-forward-level=7 -- $jlcmd`
    @test success(pipeline(cmd, stdout=stdout, stderr=stderr))
    exit()
end

