#######################################################################
# Coverage.jl
# Input: Code coverage and memory allocations
# Output: Useful things
# https://github.com/JuliaCI/Coverage.jl
#######################################################################
module Coverage
    using CoverageTools
    using LibGit2

    export FileCoverage
    export LCOV
    export analyze_malloc
    export amend_coverage_from_src!
    export clean_file
    export clean_folder
    export get_summary
    export merge_coverage_counts
    export process_cov
    export process_file
    export process_folder

    const CovCount = CoverageTools.CovCount
    const FileCoverage = CoverageTools.FileCoverage
    const amend_coverage_from_src! = CoverageTools.amend_coverage_from_src!
    const clean_file = CoverageTools.clean_file
    const clean_folder = CoverageTools.clean_folder
    const get_summary = CoverageTools.get_summary
    const iscovfile = CoverageTools.iscovfile
    const merge_coverage_counts = CoverageTools.merge_coverage_counts
    const process_cov = CoverageTools.process_cov
    const process_file = CoverageTools.process_file
    const process_folder = CoverageTools.process_folder

    include("coveralls.jl")
    include("codecovio.jl")
    include("lcov.jl")
    include("memalloc.jl")
    include("parser.jl")
end
