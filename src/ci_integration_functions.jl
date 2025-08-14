# CI Integration functions for Coverage.jl
# Simplified from CIIntegration module

"""
    detect_ci_platform()

Detect the current CI platform based on environment variables.
"""
function detect_ci_platform()
    if haskey(ENV, "GITHUB_ACTIONS") || haskey(ENV, "GITHUB_ACTION")
        return :github_actions
    elseif Base.get_bool_env("TRAVIS", false)
        return :travis
    elseif Base.get_bool_env("APPVEYOR", false)
        return :appveyor
    elseif Base.get_bool_env("CIRCLECI", false)
        return :circleci
    elseif Base.get_bool_env("JENKINS", false)
        return :jenkins
    elseif haskey(ENV, "BUILD_BUILDURI") # Azure Pipelines
        return :azure_pipelines
    elseif Base.get_bool_env("BUILDKITE", false)
        return :buildkite
    elseif Base.get_bool_env("GITLAB_CI", false)
        return :gitlab
    else
        return :unknown
    end
end

"""
    upload_to_codecov(fcs::Vector{FileCoverage}; format=:lcov, flags=nothing, name=nothing, token=nothing, dry_run=false, cleanup=true)

Process coverage data and upload to Codecov using the official uploader.
"""
function upload_to_codecov(fcs::Vector{FileCoverage};
                          format=:lcov,
                          flags=nothing,
                          name=nothing,
                          token=nothing,
                          dry_run=false,
                          cleanup=true)

    # Prepare coverage file
    @info "Preparing coverage data for Codecov..."
    coverage_file = prepare_for_codecov(fcs; format=format)

    try
        # Get codecov executable
        codecov_exe = get_codecov_executable()

        # Build command arguments
        cmd_args = [codecov_exe]

        # Add coverage file
        if format == :lcov
            push!(cmd_args, "-f", coverage_file)
        elseif format == :json
            push!(cmd_args, "-f", coverage_file)
        end

        # Add token if provided or available in environment
        upload_token = token
        if upload_token === nothing
            upload_token = get(ENV, "CODECOV_TOKEN", nothing)
        end
        if upload_token !== nothing
            push!(cmd_args, "-t", upload_token)
        end

        # Add flags if provided
        if flags !== nothing
            for flag in flags
                push!(cmd_args, "-F", flag)
            end
        end

        # Add name if provided
        if name !== nothing
            push!(cmd_args, "-n", name)
        end

        # Execute command
        if dry_run
            @info "Would execute: $(join(cmd_args, " "))"
            return true
        else
            @info "Uploading to Codecov..."
            result = run(Cmd(cmd_args); wait=true)
            success = result.exitcode == 0

            if success
                @info "Successfully uploaded to Codecov"
            else
                @error "Failed to upload to Codecov (exit code: $(result.exitcode))"
            end

            return success
        end

    finally
        if cleanup && isfile(coverage_file)
            rm(coverage_file; force=true)
            @debug "Cleaned up temporary file: $coverage_file"
        end
    end
end

"""
    upload_to_coveralls(fcs::Vector{FileCoverage}; format=:lcov, token=nothing, dry_run=false, cleanup=true)

Process coverage data and upload to Coveralls using the Universal Coverage Reporter.
"""
function upload_to_coveralls(fcs::Vector{FileCoverage};
                            format=:lcov,
                            token=nothing,
                            dry_run=false,
                            cleanup=true)

    # Prepare coverage file
    @info "Preparing coverage data for Coveralls..."
    coverage_file = prepare_for_coveralls(fcs; format=format)

    try
        # Get coveralls executable
        coveralls_exe = get_coveralls_executable()

        # Build command arguments
        cmd_args = [coveralls_exe, "report"]

        # Add coverage file
        push!(cmd_args, coverage_file)

        # Set up environment variables
        env = copy(ENV)

        # Add token if provided or available in environment
        upload_token = token
        if upload_token === nothing
            upload_token = get(ENV, "COVERALLS_REPO_TOKEN", nothing)
        end
        if upload_token !== nothing
            env["COVERALLS_REPO_TOKEN"] = upload_token
        end

        # Execute command
        if dry_run
            @info "Would execute: $(join(cmd_args, " "))"
            @info "Environment: COVERALLS_REPO_TOKEN=$(upload_token !== nothing ? "<token>" : "<not set>")"
            return true
        else
            @info "Uploading to Coveralls..."
            result = run(setenv(Cmd(cmd_args), env); wait=true)
            success = result.exitcode == 0

            if success
                @info "Successfully uploaded to Coveralls"
            else
                @error "Failed to upload to Coveralls (exit code: $(result.exitcode))"
            end

            return success
        end

    finally
        if cleanup && isfile(coverage_file)
            rm(coverage_file; force=true)
            @debug "Cleaned up temporary file: $coverage_file"
        end
    end
end

"""
    process_and_upload(; service=:both, folder="src", format=:lcov, codecov_flags=nothing, codecov_name=nothing, dry_run=false)

Convenience function to process coverage and upload to coverage services.
"""
function process_and_upload(;
                           service=:both,
                           folder="src",
                           format=:lcov,
                           codecov_flags=nothing,
                           codecov_name=nothing,
                           dry_run=false)

    @info "Processing coverage for folder: $folder"
    fcs = process_folder(folder)

    if isempty(fcs)
        @warn "No coverage data found in $folder"
        return Dict(:codecov => false, :coveralls => false)
    end

    results = Dict{Symbol,Bool}()

    if service == :codecov || service == :both
        @info "Uploading to Codecov..."
        results[:codecov] = upload_to_codecov(fcs;
                                             format=format,
                                             flags=codecov_flags,
                                             name=codecov_name,
                                             dry_run=dry_run)
    end

    if service == :coveralls || service == :both
        @info "Uploading to Coveralls..."
        results[:coveralls] = upload_to_coveralls(fcs;
                                                 format=format,
                                                 dry_run=dry_run)
    end

    return results
end
