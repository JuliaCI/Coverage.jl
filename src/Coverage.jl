module Coverage

using CoverageTools
using LibGit2
using Requires: @require

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

"""
    report_allocs(
        io::IO=stdout;
        run_cmd::Union{Nothing, Base.Cmd} = nothing,
        deps_to_monitor::Vector{Module} = Module[],
        dirs_to_monitor::Vector{String} = String[],
        process_filename::Function = process_filename_default,
        is_loading_pkg::Function = (fn, ln) -> false,
        n_rows::Int = 10,
        suppress_url::Bool = true,
    )

Reports allocations given:

 - `io::IO` IO stream. Defaults to `stdout`
 - `run_cmd` a `Base.Cmd` to run script, be sure to
   use `--track-allocation=user` or `--track-allocation=all`
 - `deps_to_monitor` a `Vector` of modules to monitor
 - `dirs_to_monitor` a `Vector` of directories to monitor
 - `n_rows::Int` the number of rows to be displayed in the
   truncated table. A value of 0 indicates no truncation.
   A positive value will truncate the table to the specified
   number of rows.
 - `suppress_url` (` = true`) suppress trying to use URLs in the output table

# Example usage

```julia
import Coverage
import PrettyTables # load report_allocs
mktempdir() do path
    open(joinpath(path, "example.jl"), "w") do io
        println(io, "for i in 1:1000")
        println(io, "    x = []")
        println(io, "    push!(x, 1)")
        println(io, "    push!(x, [1,2,3,4])")
        println(io, "    push!(x, \"stringy-string\")")
        println(io, "end")
    end
    Coverage.report_allocs(;
        run_cmd=`$(Base.julia_cmd()) --track-allocation=all \$(joinpath(path, "example.jl"))`,
        dirs_to_monitor = [path],
        process_filename = fn -> replace(fn, path=>""),
    )
end
```

Using `report_allocs` requires that you first load the `PrettyTables.jl` package.
"""
function report_allocs end

function __init__()
    @require PrettyTables = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d" include("report_allocs.jl")
    return nothing
end

end # module
