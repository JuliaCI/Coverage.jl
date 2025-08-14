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
using Coverage.CIIntegration

function parse_args(args)
    options = Dict{Symbol,Any}(
        :service => :both,
        :folder => "src",
        :format => :lcov,
        :codecov_flags => nothing,
        :codecov_name => nothing,
        :codecov_token => nothing,
        :coveralls_token => nothing,
        :dry_run => false,
        :help => false
    )

    i = 1
    while i <= length(args)
        arg = args[i]

        if arg == "--help" || arg == "-h"
            options[:help] = true
            break
        elseif arg == "--service"
            i += 1
            i <= length(args) || error("--service requires a value")
            service_str = lowercase(args[i])
            if service_str == "codecov"
                options[:service] = :codecov
            elseif service_str == "coveralls"
                options[:service] = :coveralls
            elseif service_str == "both"
                options[:service] = :both
            else
                error("Invalid service: $service_str. Use 'codecov', 'coveralls', or 'both'.")
            end
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
        elseif arg == "--codecov-flags"
            i += 1
            i <= length(args) || error("--codecov-flags requires a value")
            options[:codecov_flags] = split(args[i], ',')
        elseif arg == "--codecov-name"
            i += 1
            i <= length(args) || error("--codecov-name requires a value")
            options[:codecov_name] = args[i]
        elseif arg == "--codecov-token"
            i += 1
            i <= length(args) || error("--codecov-token requires a value")
            options[:codecov_token] = args[i]
        elseif arg == "--coveralls-token"
            i += 1
            i <= length(args) || error("--coveralls-token requires a value")
            options[:coveralls_token] = args[i]
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
        options = parse_args(ARGS)

        if options[:help]
            show_help()
            return
        end

        # Show configuration
        println("📊 Coverage Upload Configuration")
        println("Service: $(options[:service])")
        println("Folder: $(options[:folder])")
        println("Format: $(options[:format])")

        if options[:service] in [:codecov, :both]
            println("Codecov flags: $(something(options[:codecov_flags], "none"))")
            println("Codecov name: $(something(options[:codecov_name], "auto"))")
            println("Codecov token: $(options[:codecov_token] !== nothing ? "<provided>" : "from environment")")
        end

        if options[:service] in [:coveralls, :both]
            println("Coveralls token: $(options[:coveralls_token] !== nothing ? "<provided>" : "from environment")")
        end

        println("Dry run: $(options[:dry_run])")
        println()

        # Detect CI platform
        ci_platform = detect_ci_platform()
        println("🔍 Detected CI platform: $ci_platform")

        # Process and upload coverage
        results = process_and_upload(;
            service=options[:service],
            folder=options[:folder],
            format=options[:format],
            codecov_flags=options[:codecov_flags],
            codecov_name=options[:codecov_name],
            dry_run=options[:dry_run]
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
        println("❌ Error: $(string(e))")
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
