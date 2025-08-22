# CI Integration functions for Coverage.jl

"""
    upload_to_codecov(fcs::Vector{FileCoverage}; format=:lcov, flags=nothing, name=nothing, token=nothing, build_id=nothing, dry_run=false, cleanup=true)

Process coverage data and upload to Codecov using the official uploader.

# Arguments
- `fcs`: Vector of FileCoverage objects containing coverage data
- `format`: Coverage format (:lcov or :json)
- `flags`: String or Vector{String} of flags to categorize this upload (e.g., ["unittests", "julia-1.9"])
- `name`: Name for this specific upload (useful for parallel jobs)
- `token`: Codecov upload token (defaults to CODECOV_TOKEN environment variable)
- `build_id`: Build identifier to group parallel uploads (auto-detected if not provided)
- `dry_run`: If true, show what would be uploaded without actually uploading
- `cleanup`: If true, remove temporary files after upload

# Parallel Job Usage
For parallel CI jobs, use flags to distinguish different parts:
```julia
# Job 1: Unit tests on Julia 1.9
upload_to_codecov(fcs; flags=["unittests", "julia-1.9"], name="unit-tests-1.9")

# Job 2: Integration tests on Julia 1.10
upload_to_codecov(fcs; flags=["integration", "julia-1.10"], name="integration-1.10")
```
"""
function upload_to_codecov(fcs::Vector{FileCoverage};
                          format=:lcov,
                          flags=nothing,
                          name=nothing,
                          token=nothing,
                          build_id=nothing,
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
            flag_list = flags isa String ? [flags] : flags
            for flag in flag_list
                push!(cmd_args, "-F", flag)
            end
        end

        # Add name if provided
        if name !== nothing
            push!(cmd_args, "-n", name)
        end

        # Add build identifier for parallel job grouping
        if build_id !== nothing
            push!(cmd_args, "-b", string(build_id))
        end

        # Add flag to exit with non-zero on failure (instead of default exit code 0)
        push!(cmd_args, "-Z")

        # Execute command
        if dry_run
            @info "Would execute: $(join(cmd_args, " "))"
            return true
        else
            @info "Uploading to Codecov..."
            try
                result = run(Cmd(cmd_args); wait=true)
                success = result.exitcode == 0

                if success
                    @info "Successfully uploaded to Codecov"
                else
                    @error "Failed to upload to Codecov (exit code: $(result.exitcode))"
                end

                return success
            catch e
                @error "Failed to upload to Codecov" exception=e
                return false
            end
        end

    finally
        if cleanup && isfile(coverage_file)
            rm(coverage_file; force=true)
            @debug "Cleaned up temporary file: $coverage_file"
        end
    end
end

"""
    upload_to_coveralls(fcs::Vector{FileCoverage}; format=:lcov, token=nothing, parallel=nothing, job_flag=nothing, build_num=nothing, dry_run=false, cleanup=true)

Process coverage data and upload to Coveralls using the Universal Coverage Reporter.

# Arguments
- `fcs`: Vector of FileCoverage objects containing coverage data
- `format`: Coverage format (:lcov)
- `token`: Coveralls repo token (defaults to COVERALLS_REPO_TOKEN environment variable)
- `parallel`: Set to true for parallel job uploads (requires calling finish_parallel afterwards)
- `job_flag`: Flag to distinguish this job in parallel builds (e.g., "julia-1.9-linux")
- `build_num`: Build number for grouping parallel jobs (overrides COVERALLS_SERVICE_NUMBER environment variable)
- `dry_run`: If true, show what would be uploaded without actually uploading
- `cleanup`: If true, remove temporary files after upload

# Parallel Job Usage
For parallel CI jobs, set parallel=true and call finish_parallel when all jobs complete:
```julia
# Job 1: Upload with parallel flag
upload_to_coveralls(fcs; parallel=true, job_flag="julia-1.9", build_num="123")

# Job 2: Upload with parallel flag
upload_to_coveralls(fcs; parallel=true, job_flag="julia-1.10", build_num="123")

# After all jobs: Signal completion (typically in a separate "finalize" job)
finish_coveralls_parallel(build_num="123")
```
"""
function upload_to_coveralls(fcs::Vector{FileCoverage};
                            format=:lcov,
                            token=nothing,
                            parallel=nothing,
                            job_flag=nothing,
                            build_num=nothing,
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

        # Set parallel flag if requested
        if parallel === true
            env["COVERALLS_PARALLEL"] = "true"
        elseif parallel === false
            env["COVERALLS_PARALLEL"] = "false"
        end
        # If parallel=nothing, let the environment variable take precedence

        # Set job flag for distinguishing parallel jobs
        if job_flag !== nothing
            env["COVERALLS_FLAG_NAME"] = job_flag
        end

        # Set build number for grouping parallel jobs
        if build_num !== nothing
            env["COVERALLS_SERVICE_NUMBER"] = string(build_num)
            @debug "Using explicit build number for Coveralls" build_num=build_num
        elseif haskey(ENV, "COVERALLS_SERVICE_NUMBER")
            @debug "Using environment COVERALLS_SERVICE_NUMBER" service_number=ENV["COVERALLS_SERVICE_NUMBER"]
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
    process_and_upload(; service=:both, folder="src", format=:lcov, codecov_flags=nothing, codecov_name=nothing, codecov_build_id=nothing, coveralls_parallel=nothing, coveralls_job_flag=nothing, dry_run=false)

Process coverage data in the specified folder and upload to the specified service(s).

# Arguments
- `service`: Service to upload to (:codecov, :coveralls, or :both)
- `folder`: Folder to process for coverage data (default: "src")
- `format`: Coverage format (:lcov or :json)
- `codecov_flags`: Flags for Codecov upload
- `codecov_name`: Name for Codecov upload
- `codecov_build_id`: Build ID for Codecov parallel job grouping
- `coveralls_parallel`: Enable parallel mode for Coveralls (true/false)
- `coveralls_job_flag`: Job flag for Coveralls parallel identification
- `dry_run`: Show what would be uploaded without actually uploading

# Returns
Dictionary with upload results for each service
"""
function process_and_upload(; service=:both,
                           folder="src",
                           format=:lcov,
                           codecov_flags=nothing,
                           codecov_name=nothing,
                           codecov_build_id=nothing,
                           coveralls_parallel=nothing,
                           coveralls_job_flag=nothing,
                           dry_run=false)

    @info "Processing coverage for folder: $folder"
    fcs = process_folder(folder)

    if isempty(fcs)
        @warn "No coverage data found in $folder"
        return service == :both ? Dict(:codecov => false, :coveralls => false) : false
    end

    results = Dict{Symbol,Bool}()

    # Upload to Codecov
    if service in [:codecov, :both]
        try
            results[:codecov] = upload_to_codecov(fcs;
                                                 format=format,
                                                 flags=codecov_flags,
                                                 name=codecov_name,
                                                 build_id=codecov_build_id,
                                                 dry_run=dry_run)
        catch e
            results[:codecov] = CoverageUtils.handle_upload_error(e, "Codecov")
        end
    end

    # Upload to Coveralls
    if service in [:coveralls, :both]
        try
            results[:coveralls] = upload_to_coveralls(fcs;
                                                     format=format,
                                                     parallel=coveralls_parallel,
                                                     job_flag=coveralls_job_flag,
                                                     dry_run=dry_run)
        catch e
            results[:coveralls] = CoverageUtils.handle_upload_error(e, "Coveralls")
        end
    end

    return results
end

"""
    finish_coveralls_parallel(; token=nothing, build_num=nothing)

Signal to Coveralls that all parallel jobs have completed and coverage can be processed.
This should be called once after all parallel upload_to_coveralls() calls are complete.

# Arguments
- `token`: Coveralls repo token (defaults to COVERALLS_REPO_TOKEN environment variable)
- `build_num`: Build number for the parallel jobs (overrides COVERALLS_SERVICE_NUMBER environment variable)

Call this from a separate CI job that runs after all parallel coverage jobs finish.
"""
function finish_coveralls_parallel(; token=nothing, build_num=nothing)
    # Add token if provided or available in environment
    upload_token = token
    if upload_token === nothing
        upload_token = get(ENV, "COVERALLS_REPO_TOKEN", nothing)
    end
    if upload_token === nothing
        error("Coveralls token required for parallel completion. Set COVERALLS_REPO_TOKEN environment variable or pass token parameter.")
    end

    # Prepare the completion webhook payload
    payload_data = Dict("status" => "done")

    # Add build number if provided or available in environment
    service_number = build_num !== nothing ? string(build_num) : get(ENV, "COVERALLS_SERVICE_NUMBER", nothing)
    if service_number !== nothing && service_number != ""
        payload_data["build_num"] = service_number
        @info "Using build number for parallel completion" build_num=service_number
    else
        @warn "No build number available for parallel completion - this may cause issues with parallel job grouping"
    end

    payload = Dict(
        "repo_token" => upload_token,
        "payload" => payload_data
    )

    @info "Signaling Coveralls parallel job completion..."

    try
        response = HTTP.post(
            "https://coveralls.io/webhook",
            ["Content-Type" => "application/json"],
            JSON.json(payload)
        )

        if response.status == 200
            @info "✅ Successfully signaled parallel job completion to Coveralls"
            return true
        else
            @error "❌ Failed to signal parallel completion" status=response.status
            return false
        end
    catch e
        @error "❌ Error signaling parallel completion to Coveralls" exception=e
        return false
    end
end
