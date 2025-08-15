# Codecov integration functions for Coverage.jl
# Simplified from CodecovExport module

# Platform-specific codecov uploader URLs
function get_codecov_url(platform)
    if platform == :linux
        arch = Sys.ARCH == :aarch64 ? "aarch64" : "linux"
        return "https://uploader.codecov.io/latest/$arch/codecov"
    elseif platform == :macos
        return "https://uploader.codecov.io/latest/macos/codecov"
    elseif platform == :windows
        return "https://uploader.codecov.io/latest/windows/codecov.exe"
    else
        error("Unsupported platform: $platform")
    end
end

"""
    to_codecov_json(fcs::Vector{FileCoverage})

Convert FileCoverage results to Codecov JSON format.
"""
function to_codecov_json(fcs::Vector{FileCoverage})
    coverage = Dict{String,Vector{Union{Nothing,Int}}}()
    for fc in fcs
        # Codecov expects line coverage starting from line 1, but Julia coverage
        # starts with a nothing for the overall file coverage
        coverage[fc.filename] = vcat(nothing, fc.coverage)
    end
    return Dict("coverage" => coverage)
end

"""
    export_codecov_json(fcs::Vector{FileCoverage}, output_file="coverage.json")

Export coverage data to a JSON file compatible with the Codecov uploader.
"""
function export_codecov_json(fcs::Vector{FileCoverage}, output_file="coverage.json")
    CoverageUtils.ensure_output_dir(output_file)
    codecov_data = to_codecov_json(fcs)

    open(output_file, "w") do io
        JSON.print(io, codecov_data)
    end

    @info "Codecov JSON exported to: $output_file"
    return abspath(output_file)
end

"""
    prepare_for_codecov(fcs::Vector{FileCoverage}; format=:json, output_dir="coverage", filename=nothing)

Prepare coverage data for upload with the official Codecov uploader.
"""
function prepare_for_codecov(fcs::Vector{FileCoverage};
                            format=:json,
                            output_dir="coverage",
                            filename=nothing)
    mkpath(output_dir)

    if format == :json
        output_file = something(filename, joinpath(output_dir, "coverage.json"))
        return export_codecov_json(fcs, output_file)
    elseif format == :lcov
        # Use existing LCOV functionality
        output_file = something(filename, joinpath(output_dir, "coverage.info"))
        LCOV.writefile(output_file, fcs)
        @info "LCOV file exported to: $output_file"
        return abspath(output_file)
    else
        error("Unsupported format: $format. Supported formats: :json, :lcov")
    end
end

"""
    download_codecov_uploader(; force=false, install_dir=nothing)

Download the official Codecov uploader for the current platform.
"""
function download_codecov_uploader(; force=false, install_dir=nothing)
    platform = CoverageUtils.detect_platform()
    uploader_url = get_codecov_url(platform)

    # Determine installation directory
    if install_dir === nothing
        install_dir = mktempdir(; prefix="codecov_uploader_", cleanup=false)
    else
        mkpath(install_dir)
    end

    # Determine executable filename
    exec_name = platform == :windows ? "codecov.exe" : "codecov"
    exec_path = joinpath(install_dir, exec_name)

    # Check if uploader already exists and force is not set
    if !force && isfile(exec_path)
        @info "Codecov uploader already exists at: $exec_path"
        return exec_path
    end

    # Remove existing file if force is true
    if force && isfile(exec_path)
        rm(exec_path)
    end

    @info "Downloading Codecov uploader for $platform..."

    return CoverageUtils.download_binary(uploader_url, install_dir, exec_name)
end

"""
    get_codecov_executable(; auto_download=true, install_dir=nothing)

Get the path to the Codecov uploader executable, downloading it if necessary.
"""
function get_codecov_executable(; auto_download=true, install_dir=nothing)
    platform = CoverageUtils.detect_platform()
    exec_name = platform == :windows ? "codecov.exe" : "codecov"

    # First, check if codecov is available in PATH
    codecov_path = Sys.which(exec_name)
    if codecov_path !== nothing && isfile(codecov_path)
        @info "Found Codecov uploader in PATH: $codecov_path"
        return codecov_path
    end

    # Check in specified install directory
    if install_dir !== nothing
        local_path = joinpath(install_dir, exec_name)
        if isfile(local_path)
            @info "Found Codecov uploader at: $local_path"
            return local_path
        end
    end

    # Auto-download if enabled
    if auto_download
        @info "Codecov uploader not found, downloading..."
        return download_codecov_uploader(; install_dir=install_dir)
    else
        error("Codecov uploader not found. Set auto_download=true or install manually.")
    end
end
