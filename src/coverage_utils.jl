# Common utilities for Coverage.jl modules
module CoverageUtils

using Downloads

export detect_platform, ensure_output_dir, create_deprecation_message, create_script_help, parse_script_args, handle_script_error

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
        export_module = "CodecovExport"
        prepare_function = "prepare_for_codecov"
        upload_function = "upload_to_codecov"
        official_uploader = "official Codecov uploader"
    elseif service == :coveralls
        service_name = "Coveralls"
        service_url = "https://docs.coveralls.io/integrations#universal-coverage-reporter"
        export_module = "CoverallsExport"
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
    1. Use Coverage.$(export_module).$(prepare_function)(fcs) to prepare coverage data
    2. Use the $(official_uploader) to submit the data
    3. See $(service_url) for details

    For automated upload, use Coverage.CIIntegration.$(upload_function)(fcs)
    """
end

"""
    download_with_info(url::String, dest_path::String, binary_name::String, platform::Symbol)

Download a binary with standardized info messages.
"""
function download_with_info(url::String, dest_path::String, binary_name::String, platform::Symbol)
    @info "Downloading $(binary_name) for $(platform)..."
    Downloads.download(url, dest_path)
    chmod(dest_path, 0o555)  # Make executable
    @info "$(binary_name) downloaded to: $(dest_path)"
    return dest_path
end

"""
    create_script_help(script_name::String, description::String, options::Vector{Tuple{String, String}})

Create standardized help text for scripts.
"""
function create_script_help(script_name::String, description::String, options::Vector{Tuple{String, String}})
    help_text = """
    $(description)

    Usage:
        julia $(script_name) [options]

    Options:
    """

    for (option, desc) in options
        help_text *= "    $(option)\n"
        # Add description indented
        for line in split(desc, '\n')
            help_text *= "        $(line)\n"
        end
    end

    return help_text
end

"""
    parse_script_args(args::Vector{String}, valid_options::Vector{String})

Parse command line arguments for scripts with common patterns.
Returns a Dict with parsed options.
"""
function parse_script_args(args::Vector{String}, valid_options::Vector{String})
    parsed = Dict{String, Any}()
    i = 1

    while i <= length(args)
        arg = args[i]

        if arg == "--help" || arg == "-h"
            parsed["help"] = true
            return parsed
        end

        if !startswith(arg, "--")
            error("Unknown argument: $arg")
        end

        option = arg[3:end]  # Remove "--"

        if !(option in valid_options)
            error("Unknown option: --$option")
        end

        if option in ["help", "dry-run", "version"]
            # Boolean flags
            parsed[option] = true
        else
            # Options that need values
            if i == length(args)
                error("Option --$option requires a value")
            end
            parsed[option] = args[i + 1]
            i += 1
        end

        i += 1
    end

    return parsed
end

"""
    handle_script_error(e::Exception, context::String)

Standard error handling for scripts.
"""
function handle_script_error(e::Exception, context::String)
    println("❌ Error in $(context): $(string(e))")
    exit(1)
end

end # module CoverageUtils
