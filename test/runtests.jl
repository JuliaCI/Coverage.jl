#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage, Base.Test

# test our filename matching. These aren't exported functions but it's probably
# a good idea to have explicit tests for them, as they're used to match files
# that get deleted

@test Coverage.iscovfile("test.jl.cov")
@test Coverage.iscovfile("test.jl.2934.cov")
@test Coverage.iscovfile("/home/somebody/test.jl.2934.cov")
@test !Coverage.iscovfile("test.ji.2934.cov")
@test !Coverage.iscovfile("test.ji.2934.cove")
@test !Coverage.iscovfile("test.jicov")
@test !Coverage.iscovfile("test.c.cov")
@test Coverage.iscovfile("test.jl.cov", "test.jl")
@test !Coverage.iscovfile("test.jl.cov", "other.jl")
@test Coverage.iscovfile("test.jl.8392.cov", "test.jl")
@test Coverage.iscovfile("/somedir/test.jl.8392.cov", "/somedir/test.jl")
@test !Coverage.iscovfile("/otherdir/test.jl.cov", "/somedir/test.jl")

cd(Pkg.dir("Coverage")) do
    datadir = joinpath("test", "data")
    # Process a saved set of coverage data...
    r = process_file(joinpath(datadir,"Coverage.jl"))
    # ... and memory data
    analyze_malloc(datadir)
    lcov = IOBuffer()
    # we only have a single file, but we want to test on the Vector of file results
    LCOV.write(lcov, FileCoverage[r])
    open(joinpath(datadir, "expected.info")) do f
        @test takebuf_string(lcov) == readall(f)
    end

    # Test a file from scratch
    srcname = joinpath("test", "data","testparser.jl")
    covname = srcname*".cov"
    # clean out any previous coverage files. Don't use clean_folder because we
    # need to preserve the pre-baked coverage file Coverage.jl.cov
    clean_file(srcname)
    cmdstr = "include(\"$srcname\"); using Base.Test; @test f2(2) == 4"
    run(`julia --code-coverage=user -e $cmdstr`)
    r = process_file(srcname, datadir)
    # The next one is the correct one, but julia & JuliaParser don't insert a line number after the 1-line @doc -> test
    # See https://github.com/JuliaLang/julia/issues/9663 (when this is fixed, can uncomment the next line on julia 0.4)
    target = Union{Int64,Void}[nothing, nothing, nothing, nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing]
    #target = Union{Int64,Void}[nothing, nothing, nothing, nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing]
    @test r.coverage[1:length(target)] == target

    covtarget = (sum(x->x != nothing && x > 0, target), sum(x->x != nothing, target))
    @test get_summary(r) == covtarget
    @test get_summary(process_folder(datadir)) != covtarget

    #json_data = Codecov.build_json_data(Codecov.process_folder("data"))
    #@test typeof(json_data["coverage"]["data/Coverage.jl"]) == Array{Union{Int64,Void},1}

end
