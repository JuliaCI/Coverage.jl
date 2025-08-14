#!/usr/bin/env julia --project=..

"""
Upload coverage to Codecov using the official uploader.

Usage: julia scripts/upload_codecov.jl [options]
"""

include("script_utils.jl")
using .ScriptUtils
using Coverage
using ArgParse: @add_arg_table!, parse_args

function parse_codecov_args()
    s = create_base_parser("Upload coverage to Codecov")

    @add_arg_table! s begin
        "--format"
            help = "coverage format: lcov or json"
            default = "lcov"
            range_tester = x -> x in ["lcov", "json"]
        "--flags"
            help = "comma-separated list of coverage flags"
        "--name"
            help = "upload name"
        "--token"
            help = "Codecov token (or set CODECOV_TOKEN env var)"
    end

    return parse_args(s)
end

function main()
    args = parse_codecov_args()
    folder, dry_run = process_common_args(args)

    # Parse optional arguments
    format = Symbol(args["format"])
    flags = args["flags"] !== nothing ? split(args["flags"], ',') : nothing
    name = args["name"]
    token = args["token"]

    # Process and upload
    fcs = process_folder(folder)

    if isempty(fcs)
        println("❌ No coverage data found in folder: $folder")
        return 1
    end

    success = upload_to_codecov(fcs;
                               format=format,
                               flags=flags,
                               name=name,
                               token=token,
                               dry_run=dry_run)

    return success ? 0 : 1
end

exit(main_with_error_handling(main))

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
