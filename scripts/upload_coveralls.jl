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
using Coverage.CIIntegration

function parse_args(args)
    options = Dict{Symbol,Any}(
        :folder => "src",
        :format => :lcov,
        :token => nothing,
        :dry_run => false,
        :help => false
    )

    i = 1
    while i <= length(args)
        arg = args[i]

        if arg == "--help" || arg == "-h"
            options[:help] = true
            break
        elseif arg == "--folder"
            i += 1
            i <= length(args) || error("--folder requires a value")
            options[:folder] = args[i]
        elseif arg == "--format"
            i += 1
            i <= length(args) || error("--format requires a value")
            format_str = lowercase(args[i])
            if format_str == "lcov"
                options[:format] = :lcov
            elseif format_str == "json"
                options[:format] = :json
            else
                error("Invalid format: $format_str. Use 'lcov' or 'json'.")
            end
        elseif arg == "--token"
            i += 1
            i <= length(args) || error("--token requires a value")
            options[:token] = args[i]
        elseif arg == "--dry-run"
            options[:dry_run] = true
        else
            error("Unknown option: $arg")
        end

        i += 1
    end

    return options
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
        options = parse_args(ARGS)

        if options[:help]
            show_help()
            return
        end

        # Show configuration
        println("📊 Coveralls Upload Configuration")
        println("Folder: $(options[:folder])")
        println("Format: $(options[:format])")
        println("Token: $(options[:token] !== nothing ? "<provided>" : "from environment")")
        println("Dry run: $(options[:dry_run])")
        println()

        # Process coverage
        println("🔄 Processing coverage data...")
        fcs = process_folder(options[:folder])

        if isempty(fcs)
            println("❌ No coverage data found in folder: $(options[:folder])")
            exit(1)
        end

        println("✅ Found coverage data for $(length(fcs)) files")

        # Upload to Coveralls
        success = upload_to_coveralls(fcs;
            format=options[:format],
            token=options[:token],
            dry_run=options[:dry_run]
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
