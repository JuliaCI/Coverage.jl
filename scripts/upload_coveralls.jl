#!/usr/bin/env julia --project=..

"""
Easy Coveralls upload script for CI environments.

This script processes Julia coverage data and uploads it to Coveralls
using the Universal Coverage Reporter.

Usage:
    julia scripts/upload_coveralls.jl [options]

Options:
    --folder <path>     Folder to process for coverage (default: src)
    --format <format>   Coverage format: lcov or json (default: lcov)
    --token <token>     Coveralls token (or set COVERALLS_REPO_TOKEN env var)
    --dry-run          Print commands instead of executing
    --help             Show this help message

Examples:
    julia scripts/upload_coveralls.jl
    julia scripts/upload_coveralls.jl --folder src --format lcov
    julia scripts/upload_coveralls.jl --dry-run
"""

using Coverage
using ArgParse

function parse_commandline()
    s = ArgParseSettings(
        description = "Easy Coveralls upload script for CI environments.",
        epilog = """
        Examples:
          julia scripts/upload_coveralls.jl
          julia scripts/upload_coveralls.jl --folder src --format lcov
          julia scripts/upload_coveralls.jl --dry-run
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
        "--token"
            help = "Coveralls token (or set COVERALLS_REPO_TOKEN env var)"
            metavar = "TOKEN"
        "--dry-run"
            help = "Print commands instead of executing"
            action = :store_true
    end

    return parse_args(s)
end

function show_help()
    println("""
Easy Coveralls upload script for CI environments.

This script processes Julia coverage data and uploads it to Coveralls
using the Universal Coverage Reporter.

Usage:
    julia scripts/upload_coveralls.jl [options]

Options:
    --folder <path>     Folder to process for coverage (default: src)
    --format <format>   Coverage format: lcov or json (default: lcov)
    --token <token>     Coveralls token (or set COVERALLS_REPO_TOKEN env var)
    --dry-run          Print commands instead of executing
    --help             Show this help message

Examples:
    julia scripts/upload_coveralls.jl
    julia scripts/upload_coveralls.jl --folder src --format lcov
    julia scripts/upload_coveralls.jl --dry-run
""")
end

function main()
    try
        args = parse_commandline()

        # Show configuration
        println("📊 Coveralls Upload Configuration")
        println("Folder: $(args["folder"])")
        println("Format: $(args["format"])")
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

        # Upload to Coveralls
        success = upload_to_coveralls(fcs;
            format=Symbol(args["format"]),
            token=args["token"],
            dry_run=args["dry-run"]
        )

        if success
            println("🎉 Successfully uploaded to Coveralls!")
            exit(0)
        else
            println("❌ Failed to upload to Coveralls")
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
