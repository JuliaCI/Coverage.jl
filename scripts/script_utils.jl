#!/usr/bin/env julia --project=..

"""
Common utilities for Coverage.jl upload scripts.
This module provides shared functionality for all upload scripts.
"""
module ScriptUtils

using ArgParse
using Coverage

export create_base_parser, process_common_args, main_with_error_handling

"""
    create_base_parser(description::String)

Create common argument parser settings for coverage upload scripts.
"""
function create_base_parser(description::String)
    s = ArgParseSettings(
        description = description,
        version = string(pkgversion(Coverage)),
        add_version = true,
        add_help = true
    )

    @add_arg_table! s begin
        "--folder", "-f"
            help = "folder to process coverage"
            default = "src"
        "--dry-run", "-n"
            help = "show what would be uploaded without uploading"
            action = :store_true
        "--verbose", "-v"
            help = "verbose output"
            action = :store_true
    end

    return s
end

"""
    process_common_args(args)

Process arguments and handle common setup.
Returns (folder, dry_run).
"""
function process_common_args(args)
    if args["verbose"]
        ENV["JULIA_DEBUG"] = "Coverage"
    end

    return args["folder"], args["dry-run"]
end

"""
    main_with_error_handling(main_func)

Wrapper to handle errors consistently across all scripts.
"""
function main_with_error_handling(main_func)
    try
        return main_func()
    catch e
        println("❌ Error: $(sprint(Base.display_error, e))")
        return 1
    end
end

end # module ScriptUtils
