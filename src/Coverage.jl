#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################
module Coverage

export Coveralls
include("coveralls.jl")

immutable CoverageInfo
    name::UTF8String
    source::UTF8String
    coverage::Array{Union(Nothing, Int)}
end

immutable MallocInfo
    bytes::Int
    filename::UTF8String
    linenumber::Int
end

# find files in directory matching extension
export find_files
function find_files(dirs, extension)
    files = ByteString[]
    for dir in dirs
        filelist = readdir(dir)
        for file in filelist
            file = joinpath(dir, file)
            if isdir(file)
                append!(files, find_files(file))
            elseif endswith(file, extension)
                push!(files, file)
            end
        end
    end
    return files
end
find_files(file::ByteString, extension) = find_files([file], extension)

# process_cov
# Given a .cov file, return the counts for each line, where the
# lines that can't be counted are denoted with a -1
function CoverageInfo(filename::String)
    source = readall(filename)
    lines = open(readlines, filename*".cov")
    num_lines = length(lines)
    coverage = Array(Union(Nothing,Int), num_lines)
    for i = 1:num_lines
        cov_segment = lines[i][1:9]
        coverage[i] = cov_segment[9] == '-' ? nothing : int(cov_segment)
    end
    return CoverageInfo(filename, source, coverage)
end

# coveralls_process_src
# Recursively walk through a Julia package's src/ folder
# and collect coverage statistics
export process_folder
function process_folder(folder="src")
    filelist = find_files(folder, ".jl")
    ci = Array(CoverageInfo, length(filelist))
    for file in filelist
        println(file)
        try
            push!(ci, CoverageInfo(file))
        catch err
            if !isa(err,SystemError)
                rethrow(e)
            end
            # Skip
            println("Skipped $file")
        end
    end
    return ci
end

## Analyzing memory allocation
sortbybytes(a::MallocInfo, b::MallocInfo) = a.bytes < b.bytes

function analyze_malloc_files(files)
    bc = MallocInfo[]
    for filename in files
        open(filename) do file
            for (i,ln) in enumerate(eachline(file))
                tln = strip(ln)
                if !isempty(tln) && isdigit(tln[1])
                    s = split(tln)
                    b = parseint(s[1])
                    push!(bc, MallocInfo(b, filename, i))
                end
            end
        end
    end
    sort(bc, lt=sortbybytes)
end

analyze_malloc(dirs) = analyze_malloc_files(find_files(dirs, "jl.mem"))
analyze_malloc(dir::ByteString) = analyze_malloc([dir])

# Support Unix command line usage like `julia Coverage.jl $(find ~/.julia/v0.3 -name "*.jl.mem")`
if !isinteractive()
    bc = analyze_malloc_files(ARGS)
    println(bc)
end

end
