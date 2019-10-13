#######################################################################
# Coverage.jl
# Input: Code coverage and memory allocations
# Output: Useful things
# https://github.com/JuliaCI/Coverage.jl
#######################################################################
module Coverage
    using CoverageCore, LibGit2

    export process_folder, process_file
    export clean_folder, clean_file
    export process_cov, amend_coverage_from_src!
    export get_summary
    export analyze_malloc, merge_coverage_counts
    export FileCoverage
    export LCOV

    const CovCount = CoverageCore.CovCount

    const FileCoverage = CoverageCore.FileCoverage
    const get_summary = CoverageCore.get_summary
    const merge_coverage_counts = CoverageCore.merge_coverage_counts
    const process_cov = CoverageCore.process_cov
    const amend_coverage_from_src! = CoverageCore.amend_coverage_from_src!
    const process_file = CoverageCore.process_file
    const iscovfile = CoverageCore.iscovfile
    const clean_folder = CoverageCore.clean_folder
    const clean_file = CoverageCore.clean_file

    include("coveralls.jl")
    include("codecovio.jl")
    include("lcov.jl")
    include("memalloc.jl")
    include("parser.jl")
end
