# generates a lcov.info file in the format generated by `geninfo`. This format
# can be parsed by a variety of useful utilities to display coverage info

export LCOV
module LCOV

using Compat
using Coverage

function writefile(outfile::String, fcs::Vector{FileCoverage})
    open(outfile, "w") do f
        write(f, fcs)
    end
end

function write(io::IO, fcs::Vector{FileCoverage})
    for fc in fcs
        write(io, fc)
    end
end

function write(io::IO, fc::FileCoverage)
    instrumented = 0
    covered = 0
    println(io, "SF:$(fc.filename)")
    for (line, cov) in enumerate(fc.coverage)
        (lineinst, linecov) = write(io, line, cov)
        instrumented += lineinst
        covered += linecov > 0 ? 1 : 0
    end
    println(io, "LH:$covered")
    println(io, "LF:$instrumented")
    println(io, "end_of_record")
end

# returns a tuple of (instrumented, count)
function write(io::IO, line::Int, count::Int)
    println(io, "DA:$line,$count")
    (1, count)
end
function write(io::IO, line::Int, count::Nothing)
    # skipped line, nothing to do here
    (0, 0)
end

end