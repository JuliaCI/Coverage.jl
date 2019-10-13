using CoverageCore

const MallocInfo = CoverageCore.MallocInfo
const analyze_malloc = CoverageCore.analyze_malloc
const analyze_malloc_files = CoverageCore.analyze_malloc_files
const find_malloc_files = CoverageCore.find_malloc_files
const sortbybytes = CoverageCore.sortbybytes

# Support Unix command line usage like `julia Coverage.jl $(find ~/.julia/v0.6 -name "*.jl.mem")`
if abspath(PROGRAM_FILE) == joinpath(@__DIR__, "Coverage.jl")
    bc = analyze_malloc_files(ARGS)
    println(bc)
end
