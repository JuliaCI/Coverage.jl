# Common utilities for Coverage.jl modules
module CoverageUtils

using Downloads
using HTTP

export detect_platform, ensure_output_dir, create_deprecation_message, download_binary, handle_upload_error

"""
    detect_platform()

Detect the current platform for downloading appropriate binaries.
"""
function detect_platform()
    if Sys.iswindows()
        return :windows
    elseif Sys.isapple()
        return :macos
    elseif Sys.islinux()
        return :linux
    else
        error("Unsupported platform: $(Sys.MACHINE)")
    end
end

"""
    ensure_output_dir(filepath)

Ensure the directory structure exists for the given output file path.
"""
function ensure_output_dir(filepath)
    mkpath(dirname(abspath(filepath)))
end

"""
    create_deprecation_message(service::Symbol, old_function::String)

Create a standardized deprecation warning message.

# Arguments
- `service`: Either `:codecov` or `:coveralls`
- `old_function`: Name of the deprecated function (e.g., "submit", "submit_local")
"""
function create_deprecation_message(service::Symbol, old_function::String)
    if service == :codecov
        service_name = "Codecov"
        service_url = "https://docs.codecov.com/docs/codecov-uploader"
        prepare_function = "prepare_for_codecov"
        upload_function = "upload_to_codecov"
        official_uploader = "official Codecov uploader"
    elseif service == :coveralls
        service_name = "Coveralls"
        service_url = "https://docs.coveralls.io/integrations#universal-coverage-reporter"
        prepare_function = "prepare_for_coveralls"
        upload_function = "upload_to_coveralls"
        official_uploader = "Coveralls Universal Coverage Reporter"
    else
        error("Unsupported service: $service")
    end

    return """
    $(service_name).$(old_function)() is deprecated. $(service_name) no longer supports 3rd party uploaders.
    Please use the $(official_uploader) instead.

    Migration guide:
    1. Use Coverage.$(prepare_function)(fcs) to prepare coverage data
    2. Use the $(official_uploader) to submit the data
    3. See $(service_url) for details

    For automated upload, use Coverage.$(upload_function)(fcs)
    """
end

"""
    download_binary(url::String, dest_dir::String, executable_name::String)

Common function to download and set up binary executables.
Returns the path to the downloaded executable or nothing if failed.
"""
function download_binary(url::String, dest_dir::String, executable_name::String)
    exe_path = joinpath(dest_dir, executable_name)

    if isfile(exe_path)
        @info "$executable_name already exists at: $exe_path"
        return exe_path
    end

    try
        @info "Downloading from: $url"
        Downloads.download(url, exe_path)

        # Set executable permissions on Unix
        if !Sys.iswindows()
            chmod(exe_path, 0o755)
        end

        @info "$executable_name downloaded to: $exe_path"
        return exe_path
    catch e
        @error "Failed to download $executable_name" exception=e
        return nothing
    end
end

"""
    handle_upload_error(e::Exception, service::String)

Common error handler for upload failures.
"""
function handle_upload_error(e::Exception, service::String)
    error_msg = sprint(showerror, e)
    @error "Failed to upload to $service" error=error_msg

    if occursin("404", string(e))
        @warn "Check if the repository is registered with $service"
    elseif occursin("401", string(e)) || occursin("403", string(e))
        @warn "Authentication failed. Check your $service token"
    elseif occursin("timeout", lowercase(string(e)))
        @warn "Connection timeout. Check your network connection"
    end

    return false
end

end # module CoverageUtils
