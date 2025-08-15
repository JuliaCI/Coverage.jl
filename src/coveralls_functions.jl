# Coveralls integration functions for Coverage.jl
# Simplified from CoverallsExport module

# Platform-specific Coveralls reporter installation methods
function get_coveralls_info(platform)
    if platform == :linux
        arch = Sys.ARCH == :aarch64 ? "aarch64" : "x86_64"
        return (
            url = "https://github.com/coverallsapp/coverage-reporter/releases/latest/download/coveralls-linux-$arch",
            filename = "coveralls-linux-$arch",
            method = :download
        )
    elseif platform == :macos
        return (
            url = nothing,  # Use Homebrew instead
            filename = "coveralls",
            method = :homebrew,
            tap = "coverallsapp/coveralls",
            package = "coveralls"
        )
    elseif platform == :windows
        return (
            url = "https://github.com/coverallsapp/coverage-reporter/releases/latest/download/coveralls-windows.exe",
            filename = "coveralls-windows.exe",
            method = :download
        )
    else
        error("Unsupported platform: $platform")
    end
end

"""
    to_coveralls_json(fcs::Vector{FileCoverage})

Convert FileCoverage results to Coveralls JSON format.
"""
function to_coveralls_json(fcs::Vector{FileCoverage})
    source_files = Vector{Dict{String, Any}}()

    for fc in fcs
        # Normalize path for cross-platform compatibility
        name = Sys.iswindows() ? replace(fc.filename, '\\' => '/') : fc.filename

        push!(source_files, Dict{String, Any}(
            "name" => name,
            "source_digest" => "", # Coveralls will compute this
            "coverage" => fc.coverage
        ))
    end

    return Dict{String, Any}("source_files" => source_files)
end

"""
    export_coveralls_json(fcs::Vector{FileCoverage}, output_file="coveralls.json")

Export coverage data to a JSON file compatible with the Coveralls Universal Coverage Reporter.
"""
function export_coveralls_json(fcs::Vector{FileCoverage}, output_file="coveralls.json")
    CoverageUtils.ensure_output_dir(output_file)
    coveralls_data = to_coveralls_json(fcs)

    # Add git information if available
    try
        git_info = query_git_info()
        coveralls_data["git"] = git_info
    catch e
        @warn "Could not gather git information" exception=e
    end

    open(output_file, "w") do io
        JSON.print(io, coveralls_data)
    end

    @info "Coveralls JSON exported to: $output_file"
    return abspath(output_file)
end

"""
    prepare_for_coveralls(fcs::Vector{FileCoverage}; format=:lcov, output_dir="coverage", filename=nothing)

Prepare coverage data for upload with the Coveralls Universal Coverage Reporter.
"""
function prepare_for_coveralls(fcs::Vector{FileCoverage};
                              format=:lcov,
                              output_dir="coverage",
                              filename=nothing)
    mkpath(output_dir)

    if format == :lcov
        # Use existing LCOV functionality (preferred by Coveralls)
        output_file = something(filename, joinpath(output_dir, "lcov.info"))
        LCOV.writefile(output_file, fcs)
        @info "LCOV file exported to: $output_file"
        return abspath(output_file)
    elseif format == :json
        output_file = something(filename, joinpath(output_dir, "coveralls.json"))
        return export_coveralls_json(fcs, output_file)
    else
        error("Unsupported format: $format. Supported formats: :lcov, :json")
    end
end

"""
    download_coveralls_reporter(; force=false, install_dir=nothing)

Install the Coveralls Universal Coverage Reporter for the current platform.
"""
function download_coveralls_reporter(; force=false, install_dir=nothing)
    platform = CoverageUtils.detect_platform()
    reporter_info = get_coveralls_info(platform)

    if reporter_info.method == :homebrew
        return install_via_homebrew(reporter_info; force=force)
    elseif reporter_info.method == :download
        return install_via_download(reporter_info, platform; force=force, install_dir=install_dir)
    else
        error("Unsupported installation method: $(reporter_info.method)")
    end
end

"""
    install_via_homebrew(reporter_info; force=false)

Install Coveralls reporter via Homebrew (macOS).
"""
function install_via_homebrew(reporter_info; force=false)
    # Check if Homebrew is available
    brew_path = Sys.which("brew")
    if brew_path === nothing
        error("Homebrew is not installed. Please install Homebrew first: https://brew.sh")
    end

    # Check if coveralls is already installed
    if !force
        coveralls_path = Sys.which("coveralls")
        if coveralls_path !== nothing && isfile(coveralls_path)
            @info "Coveralls reporter already installed via Homebrew at: $coveralls_path"
            return coveralls_path
        end
    end

    @info "Installing Coveralls reporter via Homebrew..."

    try
        # Add the tap if it doesn't exist
        @info "Adding Homebrew tap: $(reporter_info.tap)"
        run(`brew tap $(reporter_info.tap)`; wait=true)

        # Install coveralls
        @info "Installing Coveralls reporter..."
        if force
            run(`brew reinstall $(reporter_info.package)`; wait=true)
        else
            run(`brew install $(reporter_info.package)`; wait=true)
        end

        # Get the installed path
        coveralls_path = Sys.which("coveralls")
        if coveralls_path === nothing
            error("Coveralls installation failed - command not found in PATH")
        end
        @info "Coveralls reporter installed at: $coveralls_path"
        return coveralls_path

    catch e
        error("Failed to install Coveralls reporter via Homebrew: $e")
    end
end

"""
    install_via_download(reporter_info, platform; force=false, install_dir=nothing)

Install Coveralls reporter via direct download (Linux/Windows).
"""
function install_via_download(reporter_info, platform; force=false, install_dir=nothing)
    # Determine installation directory
    if install_dir === nothing
        install_dir = mktempdir(; prefix="coveralls_reporter_", cleanup=false)
    else
        mkpath(install_dir)
    end

    exec_path = joinpath(install_dir, reporter_info.filename)

    # Check if reporter already exists and force is not set
    if !force && isfile(exec_path)
        @info "Coveralls reporter already exists at: $exec_path"
        return exec_path
    end

    # Remove existing file if force is true
    if force && isfile(exec_path)
        rm(exec_path)
    end

    @info "Downloading Coveralls Universal Coverage Reporter for $platform..."

    return CoverageUtils.download_binary(reporter_info.url, install_dir, reporter_info.filename)
end

"""
    get_coveralls_executable(; auto_download=true, install_dir=nothing)

Get the path to the Coveralls reporter executable, downloading it if necessary.
"""
function get_coveralls_executable(; auto_download=true, install_dir=nothing)
    platform = CoverageUtils.detect_platform()
    reporter_info = get_coveralls_info(platform)

    # First, check if coveralls is available in PATH
    # Try common executable names
    for exec_name in ["coveralls", "coveralls-reporter", reporter_info.filename]
        coveralls_path = Sys.which(exec_name)
        if coveralls_path !== nothing && isfile(coveralls_path)
            @info "Found Coveralls reporter in PATH: $coveralls_path"
            return coveralls_path
        end
    end

    # Check in specified install directory
    if install_dir !== nothing
        local_path = joinpath(install_dir, reporter_info.filename)
        if isfile(local_path)
            @info "Found Coveralls reporter at: $local_path"
            return local_path
        end
    end

    # Auto-download if enabled
    if auto_download
        @info "Coveralls reporter not found, downloading..."
        return download_coveralls_reporter(; install_dir=install_dir)
    else
        error("Coveralls reporter not found. Set auto_download=true or install manually.")
    end
end

"""
    query_git_info(dir=pwd())

Query git information for Coveralls submission.
"""
function query_git_info(dir=pwd())
    local repo
    try
        repo = LibGit2.GitRepoExt(dir)
        head = LibGit2.head(repo)
        head_cmt = LibGit2.peel(head)
        head_oid = LibGit2.GitHash(head_cmt)
        commit_sha = string(head_oid)

        # Safely extract author information
        author = LibGit2.author(head_cmt)
        author_name = string(author.name)
        author_email = string(author.email)

        # Safely extract committer information
        committer = LibGit2.committer(head_cmt)
        committer_name = string(committer.name)
        committer_email = string(committer.email)

        message = LibGit2.message(head_cmt)
        remote_name = "origin"
        branch = LibGit2.shortname(head)

        # determine remote url, but only if repo is not in detached state
        remote_url = ""
        if branch != "HEAD"
            try
                LibGit2.with(LibGit2.get(LibGit2.GitRemote, repo, remote_name)) do rmt
                    remote_url = LibGit2.url(rmt)
                end
            catch e
                @debug "Could not get remote URL" exception=e
                remote_url = ""
            end
        end

        # Create the git info structure
        git_info = Dict{String, Any}()
        git_info["branch"] = string(branch)
        git_info["remotes"] = Vector{Dict{String, Any}}([
            Dict{String, Any}(
                "name" => string(remote_name),
                "url" => string(remote_url)
            )
        ])
        git_info["head"] = Dict{String, Any}(
            "id" => string(commit_sha),
            "author_name" => string(author_name),
            "author_email" => string(author_email),
            "committer_name" => string(committer_name),
            "committer_email" => string(committer_email),
            "message" => string(message)
        )

        return git_info
    catch e
        @debug "Error in git operations" exception=e
        rethrow(e)
    finally
        if @isdefined repo
            LibGit2.close(repo)
        end
    end
end
