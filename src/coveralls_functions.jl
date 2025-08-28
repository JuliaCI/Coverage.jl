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
        # Get the latest version dynamically
        arch = Sys.ARCH == :aarch64 ? "aarch64" : "x86_64"
        version = get_latest_coveralls_macos_version()
        return (
            url = "https://github.com/vtjnash/coveralls-macos-binaries/releases/latest/download/coveralls-macos-$version-$arch.tar.gz",
            filename = "coveralls",
            method = :download,
            is_archive = true
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
    get_latest_coveralls_macos_version()

Get the latest version tag for coveralls-macos-binaries from GitHub API.
"""
function get_latest_coveralls_macos_version()
    try
        response = HTTP.get("https://api.github.com/repos/vtjnash/coveralls-macos-binaries/releases/latest")
        release_data = JSON.parse(String(response.body))
        tag_name = release_data["tag_name"]

        # Extract version from tag name (e.g., "v0.6.15-build.20250827235919" -> "v0.6.15")
        version_match = match(r"^(v\d+\.\d+\.\d+)", tag_name)
        if version_match !== nothing
            return version_match.captures[1]
        else
            error("Could not parse version from tag: $tag_name")
        end
    catch e
        @warn "Failed to fetch latest version, falling back to known version: $e"
        return "v0.6.15"  # Fallback to a known working version
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

    if reporter_info.method == :download
        return install_via_download(reporter_info, platform; force=force, install_dir=install_dir)
    else
        error("Unsupported installation method: $(reporter_info.method)")
    end
end
"""
    install_via_download(reporter_info, platform; force=false, install_dir=nothing)

Install Coveralls reporter via direct download.
"""
function install_via_download(reporter_info, platform; force=false, install_dir=nothing)
    # Determine installation directory
    if install_dir === nothing
        # Use scratch space for persistent storage across sessions
        install_dir = @get_scratch!("coveralls_reporter")
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

    # Handle tar.gz archives (for macOS binaries)
    if haskey(reporter_info, :is_archive) && reporter_info.is_archive
        # Download archive to temporary location
        archive_name = basename(reporter_info.url)
        archive_path = joinpath(install_dir, archive_name)

        try
            Downloads.download(reporter_info.url, archive_path)

            # Extract directly to the install directory
            run(`tar -xzf $archive_path -C $install_dir`)

            # The executable should now be in the install directory
            extracted_exec = joinpath(install_dir, reporter_info.filename)
            if isfile(extracted_exec)
                chmod(extracted_exec, 0o755)  # Make executable
                @info "Coveralls reporter installed at: $extracted_exec"

                # Clean up the archive
                rm(archive_path)

                return extracted_exec
            else
                error("Extracted executable not found at: $extracted_exec")
            end

        catch e
            # Clean up on error
            isfile(archive_path) && rm(archive_path)
            rethrow(e)
        end
    else
        # Direct binary download (Linux/Windows)
        return CoverageUtils.download_binary(reporter_info.url, install_dir, reporter_info.filename)
    end
end

"""
    get_coveralls_executable(; auto_download=true, install_dir=nothing)

Get the path to the Coveralls reporter executable, downloading it if necessary.
"""
function get_coveralls_executable(; auto_download=true, install_dir=nothing)
    platform = CoverageUtils.detect_platform()
    reporter_info = get_coveralls_info(platform)

    # Check if coveralls is available in PATH
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

    # Check default install directory (scratch space)
    default_install_dir = @get_scratch!("coveralls_reporter")
    default_path = joinpath(default_install_dir, reporter_info.filename)
    if isfile(default_path)
        @info "Found Coveralls reporter at: $default_path"
        return default_path
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
