module Coverage

using CoverageTools
using LibGit2
using Downloads
using SHA
using Artifacts
using JSON
using HTTP
using MbedTLS

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

# Modern uploader functions
export prepare_for_codecov, prepare_for_coveralls
export upload_to_codecov, upload_to_coveralls, process_and_upload
export finish_coveralls_parallel

# Internal utilities module
include("coverage_utils.jl")
using .CoverageUtils

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

# New modules for modern uploaders
include("codecov_functions.jl")
include("coveralls_functions.jl")
include("ci_integration_functions.jl")

# Legacy modules for backward compatibility
include("coveralls.jl")
include("codecovio.jl")

const readfile = CoverageTools.LCOV.readfile
const writefile = CoverageTools.LCOV.writefile

const MallocInfo = CoverageTools.MallocInfo
const analyze_malloc = CoverageTools.analyze_malloc
const analyze_malloc_files = CoverageTools.analyze_malloc_files
const find_malloc_files = CoverageTools.find_malloc_files
const sortbybytes = CoverageTools.sortbybytes

const isevaldef = CoverageTools.isevaldef
const isfuncexpr = CoverageTools.isfuncexpr
const function_body_lines = CoverageTools.function_body_lines
const function_body_lines! = CoverageTools.function_body_lines!

end # module
