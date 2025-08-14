#!/usr/bin/env julia --project=..

"""
Universal coverage upload script for CI environments.

Usage: julia scripts/upload_coverage.jl [options]
"""

include("script_utils.jl")
using .ScriptUtils
using Coverage
using ArgParse: @add_arg_table!, parse_args

function parse_coverage_args()
    s = create_base_parser("Upload coverage to multiple services")

    @add_arg_table! s begin
        "--service"
            help = "which service to upload to: codecov, coveralls, or both"
            default = "both"
            range_tester = x -> x in ["codecov", "coveralls", "both"]
        "--format"
            help = "coverage format: lcov or json"
            default = "lcov"
            range_tester = x -> x in ["lcov", "json"]
        "--codecov-flags"
            help = "comma-separated list of Codecov flags"
        "--codecov-name"
            help = "Codecov upload name"
    end

    return parse_args(s)
end

function main()
    args = parse_coverage_args()
    folder, dry_run = process_common_args(args)

    # Parse service-specific arguments
    service = Symbol(args["service"])
    format = Symbol(args["format"])
    codecov_flags = args["codecov-flags"] !== nothing ? split(args["codecov-flags"], ',') : nothing
    codecov_name = args["codecov-name"]

    # Use the integrated function
    result = process_and_upload(;
        service=service,
        folder=folder,
        format=format,
        codecov_flags=codecov_flags,
        codecov_name=codecov_name,
        dry_run=dry_run
    )

    # Check results
    if service == :both
        success = all(values(result))
        println(success ? "✅ All uploads successful" : "❌ Some uploads failed")
    else
        success = result
        println(success ? "✅ Upload successful" : "❌ Upload failed")
    end

    return success ? 0 : 1
end

exit(main_with_error_handling(main))
