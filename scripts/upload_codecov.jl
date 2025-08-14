#!/usr/bin/env julia --project=..

"""
Easy Codecov upload script for CI environments.

This script processes Julia coverage data and uploads it to Codecov
using the official Codecov uploader.

Usage:
    julia scripts/upload_codecov.jl [options]

Options:
    --folder <path>     Folder to process for coverage (default: src)
    --format <format>   Coverage format: lcov or json (default: lcov)
    --flags <flags>     Comma-separated list of coverage flags
    --name <name>       Upload name
    --token <token>     Codecov token (or set CODECOV_TOKEN env var)
    --dry-run          Print commands instead of executing
    --help             Show this help message

Examples:
    julia scripts/upload_codecov.jl
    julia scripts/upload_codecov.jl --folder src --format lcov --flags julia
    julia scripts/upload_codecov.jl --dry-run
"""

using Coverage

using Coverage
using ArgParse

function parse_commandline()
    s = ArgParseSettings(
        description = "Easy Codecov upload script for CI environments.",
        epilog = """
        Examples:
          julia scripts/upload_codecov.jl
          julia scripts/upload_codecov.jl --folder src --format lcov --flags julia
          julia scripts/upload_codecov.jl --dry-run
        """,
        add_version = true,
        version = pkgversion(Coverage)
    )

    @add_arg_table! s begin
        "--folder"
            help = "Folder to process for coverage"
            default = "src"
            metavar = "PATH"
        "--format"
            help = "Coverage format: lcov or json"
            default = "lcov"
            range_tester = x -> x in ["lcov", "json"]
            metavar = "FORMAT"
        "--flags"
            help = "Comma-separated list of coverage flags"
            metavar = "FLAGS"
        "--name"
            help = "Upload name"
            metavar = "NAME"
        "--token"
            help = "Codecov token (or set CODECOV_TOKEN env var)"
            metavar = "TOKEN"
        "--dry-run"
            help = "Print commands instead of executing"
            action = :store_true
    end

    return parse_args(s)
end

function main()
    try
        args = parse_commandline()

        # Show configuration
        println("📊 Codecov Upload Configuration")
        println("Folder: $(args["folder"])")
        println("Format: $(args["format"])")

        # Parse flags if provided
        flags = nothing
        if args["flags"] !== nothing
            flags = split(args["flags"], ',')
            println("Flags: $(join(flags, ","))")
        else
            println("Flags: none")
        end

        println("Name: $(something(args["name"], "auto"))")
        println("Token: $(args["token"] !== nothing ? "<provided>" : "from environment")")
        println("Dry run: $(args["dry-run"])")
        println()

        # Process coverage
        println("🔄 Processing coverage data...")
        fcs = process_folder(args["folder"])

        if isempty(fcs)
            println("❌ No coverage data found in folder: $(args["folder"])")
            exit(1)
        end

        println("✅ Found coverage data for $(length(fcs)) files")

        # Upload to Codecov
        success = upload_to_codecov(fcs;
            format=Symbol(args["format"]),
            flags=flags,
            name=args["name"],
            token=args["token"],
            dry_run=args["dry-run"]
        )

        if success
            println("🎉 Successfully uploaded to Codecov!")
            exit(0)
        else
            println("❌ Failed to upload to Codecov")
            exit(1)
        end

    catch e
        println("❌ Error: $(sprint(Base.display_error, e))")
        exit(1)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
