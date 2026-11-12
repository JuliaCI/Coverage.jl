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
        JSON.json(io, codecov_data)
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
        # Use scratch space for persistent storage across sessions
        install_dir = @get_scratch!("codecov_uploader")
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

# The Codecov CLI is pinned so that every download is checked against a known SHA-256.
const CODECOV_CLI_VERSION = "v11.3.2"
const CODECOV_CLI_SHA256 = Dict(
    "codecovcli_linux" => "8e1bfb71661378530f6ea21e82b414095899e565cbb4cf555c613064be17b973",
    "codecovcli_linux_arm64" => "a4b71cac685742e272e7cfd4a390cafc3736f57ebc3cf7ba2e24010f19c7f23f",
    "codecovcli_alpine_x86_64" => "8ad26ddd1e506eef499b4ef845b8039063835950141a77e53ed95ed7a063a990",
    "codecovcli_alpine_arm64" => "01cfbf0998f0335475da48b43edae2d391f9cf975f64f9b2212c17be6471657f",
    "codecovcli_macos" => "c7957a4c7a0f80eee58f53cd8ec7ec6cbdacffdbabb427bdfc2ce2a23f794164",
    "codecovcli_windows.exe" => "0ed5e32ac608d32e75d20ecfcb0b4a533a038ca3344285e715677bd91ae9a5f4",
)

"""
    codecov_cli_asset()

The name of the Codecov CLI release asset for the current platform.
"""
function codecov_cli_asset()
    platform = CoverageUtils.detect_platform()
    platform == :windows && return "codecovcli_windows.exe"
    # The macOS build is universal.
    platform == :macos && return "codecovcli_macos"
    # 32-bit Julia on a 64-bit host runs the 64-bit build, as it did the legacy uploader.
    if Sys.ARCH in (:x86_64, :i686)
        return occursin("musl", Sys.MACHINE) ? "codecovcli_alpine_x86_64" : "codecovcli_linux"
    elseif Sys.ARCH == :aarch64
        return occursin("musl", Sys.MACHINE) ? "codecovcli_alpine_arm64" : "codecovcli_linux_arm64"
    end
    error("The Codecov CLI has no build for $(Sys.MACHINE)")
end

file_sha256(path) = bytes2hex(open(SHA.sha256, path))

"""
    download_codecov_cli(; force=false, install_dir=nothing)

Download the pinned Codecov CLI for the current platform and check its SHA-256.
"""
function download_codecov_cli(; force=false, install_dir=nothing)
    asset = codecov_cli_asset()
    expected = CODECOV_CLI_SHA256[asset]
    install_dir = something(install_dir, @get_scratch!("codecov_cli"))
    mkpath(install_dir)
    exec_path = joinpath(install_dir, "codecov-$(CODECOV_CLI_VERSION)" * (Sys.iswindows() ? ".exe" : ""))
    if !force && isfile(exec_path) && file_sha256(exec_path) == expected
        @info "Codecov CLI already exists at: $exec_path"
        return exec_path
    end

    url = "https://github.com/codecov/codecov-cli/releases/download/$(CODECOV_CLI_VERSION)/$(asset)"
    @info "Downloading Codecov CLI $(CODECOV_CLI_VERSION) from: $url"
    tmp_path = tempname(install_dir)
    try
        Downloads.download(url, tmp_path)
        digest = file_sha256(tmp_path)
        if digest != expected
            error("The Codecov CLI download has SHA-256 $digest, expected $expected")
        end
        chmod(tmp_path, 0o755)
        mv(tmp_path, exec_path; force=true)
    finally
        rm(tmp_path; force=true)
    end
    return exec_path
end

"""
    get_codecov_cli_executable(; auto_download=true, install_dir=nothing)

Get the path to the Codecov CLI, using a `codecov` in PATH if it is the CLI, or downloading it.
"""
function get_codecov_cli_executable(; auto_download=true, install_dir=nothing)
    codecov_path = Sys.which(Sys.iswindows() ? "codecov.exe" : "codecov")
    if codecov_path !== nothing
        # A `codecov` in PATH may be the legacy uploader, which takes other arguments.
        version = try
            read(`$codecov_path --version`, String)
        catch
            ""
        end
        if startswith(version, "codecovcli")
            @info "Found Codecov CLI in PATH: $codecov_path"
            return codecov_path
        end
    end
    if auto_download
        return download_codecov_cli(; install_dir=install_dir)
    else
        error("Codecov CLI not found. Set auto_download=true or install it in PATH.")
    end
end

"""
    codecov_unprotected_branch(env=ENV)

The branch name, in the form `owner:branch`, of a pull request build on GitHub Actions or
Buildkite, or `nothing` outside one. Codecov takes an upload without a token for such a branch.
"""
function codecov_unprotected_branch(env=ENV)
    if get(env, "GITHUB_ACTIONS", "") == "true" &&
            startswith(get(env, "GITHUB_EVENT_NAME", ""), "pull_request")
        event_path = get(env, "GITHUB_EVENT_PATH", "")
        isfile(event_path) || return nothing
        event = JSON.parsefile(event_path)
        pull_request = get(event, "pull_request", nothing)
        pull_request isa AbstractDict || return nothing
        head = get(pull_request, "head", nothing)
        head isa AbstractDict || return nothing
        label = get(head, "label", nothing)
        return label isa AbstractString && occursin(':', label) ? String(label) : nothing
    elseif get(env, "BUILDKITE", "") == "true" &&
            get(env, "BUILDKITE_PULL_REQUEST", "false") ∉ ("", "false")
        branch = get(env, "BUILDKITE_BRANCH", "")
        isempty(branch) && return nothing
        # Buildkite can already prefix the branches of forks with their owner.
        occursin(':', branch) && return branch
        m = match(r"github\.com[/:]([^/]+)/", get(env, "BUILDKITE_PULL_REQUEST_REPO", ""))
        m === nothing && return nothing
        return "$(m[1]):$(branch)"
    end
    return nothing
end
