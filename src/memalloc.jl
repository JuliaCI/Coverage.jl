## Analyzing memory allocation

immutable MallocInfo
    bytes::Int
    filename::Compat.UTF8String
    linenumber::Int
end

sortbybytes(a::MallocInfo, b::MallocInfo) = a.bytes < b.bytes

"""
    analyze_malloc_files(files) -> Vector{MallocInfo}

Iterates through the given list of filenames and return a `Vector` of
`MallocInfo`s with allocation information.
"""
function analyze_malloc_files(files)
    bc = MallocInfo[]
    for filename in files
        open(filename) do file
            for (i,ln) in enumerate(eachline(file))
                tln = strip(ln)
                if !isempty(tln) && isdigit(tln[1])
                    s = split(tln)
                    b = parse(Int, s[1])
                    push!(bc, MallocInfo(b, filename, i))
                end
            end
        end
    end
    sort(bc, lt=sortbybytes)
end

function find_malloc_files(dirs)
    files = Compat.String[]
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
find_malloc_files(file::Compat.String) = find_malloc_files([file])

analyze_malloc(dirs) = analyze_malloc_files(find_malloc_files(dirs))
analyze_malloc(dir::Compat.String) = analyze_malloc([dir])

isfuncexpr(ex::Expr) =
    ex.head == :function || (ex.head == :(=) && typeof(ex.args[1]) == Expr && ex.args[1].head == :call)
isfuncexpr(arg) = false

# Support Unix command line usage like `julia Coverage.jl $(find ~/.julia/v0.6 -name "*.jl.mem")`
if abspath(PROGRAM_FILE) == joinpath(@__DIR__, "Coverage.jl")
    bc = analyze_malloc_files(ARGS)
    println(bc)
end
