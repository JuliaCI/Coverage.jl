import CoverageTools

const MallocInfo = CoverageTools.MallocInfo
const analyze_malloc = CoverageTools.analyze_malloc
const analyze_malloc_files = CoverageTools.analyze_malloc_files
const find_malloc_files = CoverageTools.find_malloc_files
const sortbybytes = CoverageTools.sortbybytes

# Support Unix command line usage like `julia Coverage.jl $(find ~/.julia/v0.6 -name "*.jl.mem")`
if abspath(PROGRAM_FILE) == joinpath(@__DIR__, "Coverage.jl")
    bc = analyze_malloc_files(ARGS)
    println(bc)
end
