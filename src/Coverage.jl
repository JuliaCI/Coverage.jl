#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################
module Coverage

    import JuliaParser.Parser
    using Compat

    export process_cov, amend_coverage_from_src!
    export coverage_file, coverage_folder
    export analyze_malloc

    # process_cov
    # Convert a Julia .cov file into an array of (counts, lines)
    #
    # Input:
    # filename          Coverage file to open
    #
    # Output:
    # coverage          Array of coverage counts by line. Count
    #                   will be `nothing` if no count possible
    function process_cov(filename)
        if !isfile(filename)
            srcname, ext = splitext(filename)
            lines = open(srcname) do fp
                readlines(fp)
            end
            coverage = Array(Union(Nothing,Int), length(lines))
            return fill!(coverage, nothing)
        end
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


    # amend_coverage_from_src!
    # The code coverage functionality in Julia can miss code lines, which
    # will be incorrectly recorded as `nothing` but should instead be 0
    #
    # Input:
    # coverage          Array of coverage counts by line (from process_cov)
    # srcname           File name for a .jl file
    function amend_coverage_from_src!(coverage, srcname)
        # To make sure things stay in sync, parse the file position
        # corresonding to each new line
        linepos = Int[]
        open(srcname) do io
            while !eof(io)
                push!(linepos, position(io))
                readline(io)
            end
            push!(linepos, position(io))
        end
        open(srcname) do io
            while !eof(io)
                pos = position(io)
                linestart = minimum(searchsorted(linepos, pos))
                ast = Parser.parse(io)
                isa(ast, Expr) || continue
                flines = function_body_lines(ast)
                if !isempty(flines)
                    flines += linestart-1
                    for l in flines
                        if coverage[l] == nothing
                            coverage[l] = 0
                        end
                    end
                end
            end
        end
        coverage
    end


    function coverage_file(filename)
        results = Coveralls.process_file(filename)
        coverage = results["coverage"]
        tot = sum(x->x!=nothing, coverage)
        covered = sum(x->x!=nothing && x>0, coverage)
        covered, tot
    end
    function coverage_folder(folder="src")
        results = Coveralls.process_folder(folder)
        tot = covered = 0
        for item in results
            coverage = item["coverage"]
            tot += sum(x->x!=nothing, coverage)
            covered += sum(x->x!=nothing && x>0, coverage)
        end
        covered, tot
    end

    function_body_lines(ast) = function_body_lines!(Int[], ast, false)
    function_body_lines!(flines, arg, infunction) = flines
    function function_body_lines!(flines, node::LineNumberNode, infunction)
        line = node.line
        if infunction
            push!(flines, line)
        end
        flines
    end
    function function_body_lines!(flines, ast::Expr, infunction)
        if ast.head == :line
            line = ast.args[1]
            if infunction
                push!(flines, line)
            end
            return flines
        end
        infunction |= isfuncexpr(ast)
        for arg in ast.args
            flines = function_body_lines!(flines, arg, infunction)
        end
        flines
    end

    export Coveralls
    module Coveralls
        using Requests
        using Coverage
        using JSON
        using Compat

        # coveralls_process_file
        # Given a .jl file, return the Coveralls.io dictionary for this
        # file by reading in the file and its matching .cov. Don't convert
        # to JSON yet, just return dictionary.
        # https://coveralls.io/docs/api
        # {
        #   "name" : "$filename"
        #   "source": "...\n....\n...."
        #   "coverage": [null, 1, null]
        # }
        export process_file
        function process_file(filename)
            return @compat Dict("name" => filename,
                    "source" => readall(filename),
                    "coverage" => amend_coverage_from_src!(process_cov(filename*".cov"), filename))
        end

        # coveralls_process_src
        # Recursively walk through a Julia package's src/ folder
        # and collect coverage statistics
        export process_folder
        function process_folder(folder="src")
            source_files=Any[]
            filelist = readdir(folder)
            for file in filelist
                fullfile = joinpath(folder,file)
                println(fullfile)
                if isfile(fullfile)
                    try
                        new_sf = process_file(fullfile)
                        push!(source_files, new_sf)
                    catch e
#                         if !isa(e,SystemError)
#                             rethrow(e)
#                         end
                        # Skip
                        println("Skipped $fullfile")
                    end
                else isdir(fullfile)
                    append!(source_files, process_folder(fullfile))
                end
            end
            return source_files
        end

        # submit
        # Submit coverage to Coveralls.io
        # https://coveralls.io/docs/api
        # {
        #   "service_job_id": "1234567890",
        #   "service_name": "travis-ci",
        #   "source_files": [
        #     {
        #       "name": "example.rb",
        #       "source": "def four\n  4\nend",
        #       "coverage": [null, 1, null]
        #     },
        #     {
        #       "name": "lib/two.rb",
        #       "source": "def seven\n  eight\n  nine\nend",
        #       "coverage": [null, 1, 0, null]
        #     }
        #   ]
        # }

        import Base.Git
        function query_git_info(dir="")
            commit_sha = Git.readchomp(`rev-parse HEAD`, dir=dir)
            author_name = Git.readchomp(`log -1 --pretty=format:"%aN"`, dir=dir)
            author_email = Git.readchomp(`log -1 --pretty=format:"%aE"`, dir=dir)
            committer_name = Git.readchomp(`log -1 --pretty=format:"%cN"`, dir=dir)
            committer_email = Git.readchomp(`log -1 --pretty=format:"%cE"`, dir=dir)
            branch = Git.branch(dir=dir)
            message = Git.readchomp(`log -1 --pretty=format:"%s"`, dir=dir)
            remote = Git.readchomp(`config --get remote.origin.url`, dir=dir)

            # Normalize remote url to https
            remote = "https" * Git.normalize_url(remote)[4:end]

            return @compat Dict(
                "branch" => branch,
                "remotes" => [
                    @compat Dict(
                        "name" => "origin",
                        "url" => remote
                    )
                ],
                "head" => @compat Dict(
                    "id" => commit_sha,
                    "author_name" => author_name,
                    "author_email" => author_email,
                    "committer_name" => committer_email,
                    "committer_email" => committer_email,
                    "message" => message
                )
            )
        end

        export submit, submit_token
        function submit(source_files)
            data = @compat Dict("service_job_id" => ENV["TRAVIS_JOB_ID"],
                    "service_name" => "travis-ci",
                    "source_files" => source_files)

            r = Requests.post(URI("https://coveralls.io/api/v1/jobs"), files =
                [FileParam(JSON.json(data),"application/json","json_file","coverage.json")])
            dump(r.data)
        end

        # git_info can be either a dict or a function that returns a dict
        function submit_token(source_files, git_info=query_git_info)
            data = @compat Dict("repo_token" => ENV["REPO_TOKEN"],
                    "source_files" => source_files)

            # Attempt to parse git info via git_info, unless the user explicitly disables it by setting git_info to nothing
            try
                if isa(git_info, Function)
                    data["git"] = git_info()
                elseif isa(git_info, Dict)
                    data["git"] = git_info
                end
            end

            r = post(URI("https://coveralls.io/api/v1/jobs"), files =
                [FileParam(JSON.json(data),"application/json","json_file","coverage.json")])
            dump(r.data)
        end
    end  # module Coveralls

    include("codecovio.jl")

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

    isfuncexpr(ex::Expr) =
        ex.head == :function || (ex.head == :(=) && typeof(ex.args[1]) == Expr && ex.args[1].head == :call)
    isfuncexpr(arg) = false

    # Support Unix command line usage like `julia Coverage.jl $(find ~/.julia/v0.3 -name "*.jl.mem")`
    if !isinteractive()
        bc = analyze_malloc_files(ARGS)
        println(bc)
    end
end
