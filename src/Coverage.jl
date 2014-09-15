#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################
module Coverage

export Coveralls
include("coveralls.jl")

# process_cov
# Given a .cov file, return the counts for each line, where the
# lines that can't be counted are denoted with a -1
export process_cov
function process_cov(filename)
    fp = open(filename, "r")
    lines = readlines(fp)
    num_lines = length(lines)
    coverage = Array(Union(Nothing,Int), num_lines)
    for i = 1:num_lines
        cov_segment = lines[i][1:9]
        coverage[i] = cov_segment[9] == '-' ? nothing : int(cov_segment)
    end
    close(fp)
    return coverage
end

export src_files
function src_files(;folder="src", pkg="")
    source_files = String[]

    # Prioritize pkg keyword
    if pkg != ""
        folder = Pkg.dir(pkg)*"/src"
    end

    filelist = readdir(folder)
    for file in filelist
        fullfile = joinpath(folder,file)
        if isfile(fullfile) && endswith(fullfile, ".jl")
            push!(source_files, fullfile)
        elseif isdir(fullfile)
            append!(source_files, src_files(folder=fullfile))
        end
    end
    return source_files
end


## Analyzing memory allocation
immutable MallocInfo
    bytes::Int
    filename::UTF8String
    linenumber::Int
end

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

function find_malloc_files(dirs)
    files = ByteString[]
    for dir in dirs
        filelist = readdir(dir)
        for file in filelist
            file = joinpath(dir, file)
            if isdir(file)
                append!(files, find_malloc_files(file))
            elseif endswith(file, "jl.mem")
                push!(files, file)
            end
        end
    end
    files
end
find_malloc_files(file::ByteString) = find_malloc_files([file])

analyze_malloc(dirs) = analyze_malloc_files(find_malloc_files(dirs))
analyze_malloc(dir::ByteString) = analyze_malloc([dir])

# Support Unix command line usage like `julia Coverage.jl $(find ~/.julia/v0.3 -name "*.jl.mem")`
if !isinteractive()
    bc = analyze_malloc_files(ARGS)
    println(bc)
end

end
