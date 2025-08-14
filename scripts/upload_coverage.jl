#!/usr/bin/env julia --project=..

"""
Universal coverage upload script for CI environments.

This script processes Julia coverage data and uploads it to both
Codecov and Coveralls using their official uploaders.

Usage:
    julia scripts/upload_coverage.jl [options]

Options:
    --service <service>   Which service to upload to: codecov, coveralls, or both (default: both)
    --folder <path>       Folder to process for coverage (default: src)
    --format <format>     Coverage format: lcov or json (default: lcov)
    --codecov-flags <flags>  Comma-separated list of Codecov flags
    --codecov-name <name>    Codecov upload name
    --codecov-token <token>  Codecov token (or set CODECOV_TOKEN env var)
    --coveralls-token <token> Coveralls token (or set COVERALLS_REPO_TOKEN env var)
    --dry-run            Print commands instead of executing
    --help               Show this help message

Examples:
    julia scripts/upload_coverage.jl
    julia scripts/upload_coverage.jl --service codecov --codecov-flags julia
    julia scripts/upload_coverage.jl --service coveralls --format lcov
    julia scripts/upload_coverage.jl --dry-run
"""

using Coverage
using ArgParse

function parse_commandline()
    s = ArgParseSettings(
        description = "Universal coverage upload script for CI environments.",
        epilog = """
        Examples:
          julia scripts/upload_coverage.jl
          julia scripts/upload_coverage.jl --service codecov --codecov-flags julia
          julia scripts/upload_coverage.jl --service coveralls --format lcov
          julia scripts/upload_coverage.jl --dry-run
        """,
        add_version = true,
        version = pkgversion(Coverage)
    )

    @add_arg_table! s begin
        "--service"
            help = "Which service to upload to: codecov, coveralls, or both"
            default = "both"
            range_tester = x -> x in ["codecov", "coveralls", "both"]
            metavar = "SERVICE"
        "--folder"
            help = "Folder to process for coverage"
            default = "src"
            metavar = "PATH"
        "--format"
            help = "Coverage format: lcov or json"
            default = "lcov"
            range_tester = x -> x in ["lcov", "json"]
            metavar = "FORMAT"
        "--codecov-flags"
            help = "Comma-separated list of Codecov flags"
            metavar = "FLAGS"
        "--codecov-name"
            help = "Codecov upload name"
            metavar = "NAME"
        "--codecov-token"
            help = "Codecov token (or set CODECOV_TOKEN env var)"
            metavar = "TOKEN"
        "--coveralls-token"
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
Universal coverage upload script for CI environments.

This script processes Julia coverage data and uploads it to both
Codecov and Coveralls using their official uploaders.

Usage:
    julia scripts/upload_coverage.jl [options]

Options:
    --service <service>   Which service to upload to: codecov, coveralls, or both (default: both)
    --folder <path>       Folder to process for coverage (default: src)
    --format <format>     Coverage format: lcov or json (default: lcov)
    --codecov-flags <flags>  Comma-separated list of Codecov flags
    --codecov-name <name>    Codecov upload name
    --codecov-token <token>  Codecov token (or set CODECOV_TOKEN env var)
    --coveralls-token <token> Coveralls token (or set COVERALLS_REPO_TOKEN env var)
    --dry-run            Print commands instead of executing
    --help               Show this help message

Examples:
    julia scripts/upload_coverage.jl
    julia scripts/upload_coverage.jl --service codecov --codecov-flags julia
    julia scripts/upload_coverage.jl --service coveralls --format lcov
    julia scripts/upload_coverage.jl --dry-run
""")
end

function main()
    try
        args = parse_commandline()

        # Show configuration
        println("📊 Coverage Upload Configuration")
        println("Service: $(args["service"])")
        println("Folder: $(args["folder"])")
        println("Format: $(args["format"])")

        service_sym = Symbol(args["service"])

        if service_sym in [:codecov, :both]
            # Parse codecov flags if provided
            codecov_flags = nothing
            if args["codecov-flags"] !== nothing
                codecov_flags = split(args["codecov-flags"], ',')
                println("Codecov flags: $(join(codecov_flags, ","))")
            else
                println("Codecov flags: none")
            end
            println("Codecov name: $(something(args["codecov-name"], "auto"))")
            println("Codecov token: $(args["codecov-token"] !== nothing ? "<provided>" : "from environment")")
        else
            codecov_flags = nothing
        end

        if service_sym in [:coveralls, :both]
            println("Coveralls token: $(args["coveralls-token"] !== nothing ? "<provided>" : "from environment")")
        end

        println("Dry run: $(args["dry-run"])")
        println()

        # Detect CI platform
        ci_platform = detect_ci_platform()
        println("🔍 Detected CI platform: $ci_platform")

        # Process and upload coverage
        results = process_and_upload(;
            service=service_sym,
            folder=args["folder"],
            format=Symbol(args["format"]),
            codecov_flags=codecov_flags,
            codecov_name=args["codecov-name"],
            dry_run=args["dry-run"]
        )

        # Check results
        success = true
        for (service, result) in results
            if result
                println("✅ Successfully uploaded to $service")
            else
                println("❌ Failed to upload to $service")
                success = false
            end
        end

        if success
            println("🎉 All uploads completed successfully!")
            exit(0)
        else
            println("❌ Some uploads failed")
            exit(1)
        end

    catch e
        println("❌ Error: $(sprint(Base.display_error, e))")
        if isa(e, InterruptException)
            println("Interrupted by user")
        else
            # Show stack trace for debugging
            println("Stack trace:")
            for (exc, bt) in Base.catch_stack()
                showerror(stdout, exc, bt)
                println()
            end
        end
        exit(1)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
