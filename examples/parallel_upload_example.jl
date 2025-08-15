# Example: Simple parallel coverage upload using process_and_upload
# This demonstrates the easy way to use the new parallel features

using Coverage

# For simple parallel workflows, you can use process_and_upload with :both service
# This automatically handles both Codecov and Coveralls with parallel options

# Example 1: Basic parallel upload
results = Coverage.process_and_upload(;
    service=:both,
    folder="src",
    codecov_flags=["julia-1.9", "linux"],
    codecov_build_id=get(ENV, "BUILD_ID", nothing),
    coveralls_parallel=true,
    coveralls_job_flag="julia-1.9-linux",
    dry_run=false  # Set to true for testing
)

# Example 2: More comprehensive parallel setup
julia_version = "julia-$(VERSION.major).$(VERSION.minor)"
platform = Sys.islinux() ? "linux" : Sys.isapple() ? "macos" : "windows"
build_id = get(ENV, "BUILDKITE_BUILD_NUMBER", get(ENV, "GITHUB_RUN_ID", nothing))

results = Coverage.process_and_upload(;
    service=:both,
    folder="src",
    codecov_flags=[julia_version, platform, "coverage"],
    codecov_name="coverage-$(platform)-$(julia_version)",
    codecov_build_id=build_id,
    coveralls_parallel=true,
    coveralls_job_flag="$(julia_version)-$(platform)",
    dry_run=false
)

@info "Upload results" results

# After all parallel jobs complete, call finish_coveralls_parallel()
# (Usually in a separate CI job)
# Coverage.finish_coveralls_parallel()
