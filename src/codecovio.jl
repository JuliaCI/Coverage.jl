export Codecov
module Codecov
    using Requests
    using Coverage
    using JSON
    using Compat

    #=
    Example of input wanted by Codecov

    {
      "coverage": {
        "path/to/file.py": [null, 1, 0, null, true, 0, 0, 1, 1],
        "path/to/other.py": [null, 0, 1, 1, "1/3", null]
      },
      "messages": {
        "path/to/other.py": {
          "1": "custom message for line 1"
        }
      }
    }
    =#


    # process_file
    # Given a .jl file, return the Codecov.io dictionary for this
    # file by reading in the file and its matching .cov. 
    export process_file
    function process_file(filename)
        cov = vcat(nothing, amend_coverage_from_src!(process_cov(filename*".cov"), filename))
        return (filename, cov)
    end
    function process_file(filename,folder)
        cov = vcat(nothing, amend_coverage_from_src!(process_cov_with_pids(filename,folder), filename))
        return (filename, cov)
    end
    
    # process_cov_with_pids
    # Given a .jl file, return the Codecov.io dictionary for this
    # file by reading in the correct file and its matching .{pid}.covs 
    function process_cov_with_pids(filename,folder)
        files = readdir(folder)
        files = map!( file -> joinpath(folder,file),files)
        filter!( file -> contains(file,filename) && contains(file,".cov"),files)
        if isempty(files)
            srcname, ext = splitext(filename)
            lines = open(srcname) do fp
                readlines(fp)
            end
            coverage = Array(Union(Nothing,Int), length(lines))
            return fill!(coverage, nothing)
        end
        full_coverage = Array(Union(Nothing,Int), 0)
        for file in files
            fp = open(file, "r")
            lines = readlines(fp)
            num_lines = length(lines)
            coverage = Array(Union(Nothing,Int), num_lines)
            for i = 1:num_lines
                cov_segment = lines[i][1:9]
                coverage[i] = cov_segment[9] == '-' ? nothing : int(cov_segment)
            end
            close(fp)
            full_coverage = merge_coverage_counts(full_coverage,coverage)
        end
        return full_coverage
    end

    # process_folder
    # Recursively walk through a Julia package's src/ folder and collect
    # coverage statistics in Codecov format
    export process_folder
    function process_folder(folder="src")
        source_files = Any[]
        filelist = readdir(folder)
        for file in filelist
            fullfile = joinpath(folder,file)
            if isfile(fullfile)
                try
                    new_sf = process_file(fullfile,folder)
                    push!(source_files, new_sf)
                catch e
                    # Skip, probably a .cov file...
                    println("Skipped $fullfile")
                end
            else isdir(fullfile)
                append!(source_files, process_folder(fullfile))
            end
        end
        return source_files
    end

    # Turn vector of filename : coverage pairs into a dictionary
    function build_json_data(source_files)
        cov = Dict()
        for file in source_files
            cov[file[1]] = file[2]
        end
        return @compat Dict("coverage" => cov)
    end

    # submit
    # Submit coverage to Codecov.io
    # https://codecov.io/api#post-json-report
    export submit, submit_token
    import Base.Git
    function submit(source_files)        
        data = build_json_data(source_files)
        branch = ENV["TRAVIS_BRANCH"]
        pull_request = ENV["TRAVIS_PULL_REQUEST"]
        job = ENV["TRAVIS_JOB_ID"]
        slug = ENV["TRAVIS_REPO_SLUG"]
        build = ENV["TRAVIS_JOB_NUMBER"]
        commit = ENV["TRAVIS_COMMIT"]
        uri_str = "https://codecov.io/upload/v2?service=travis-org&branch=$(branch)&commit=$(commit)&build=$(build)&pull_request=$(pull_request)&job=$(job)&slug=$(slug)"
        println("$uri_str")

        heads  = @compat Dict("Content-Type" => "application/json")
        r = Requests.post(
                URI(uri_str);
                json = data, headers = heads)
        dump(r)
    end

    function submit_token(source_files,commit=Git.readchomp(`rev-parse HEAD`, dir=""),branch=Git.branch(dir=""))
        repo_token = ENV["REPO_TOKEN"]
        data = build_json_data(source_files)
        heads  = @compat Dict("Content-Type" => "application/json")
        r = Requests.post(
                URI("https://codecov.io/upload/v2?&token=$(repo_token)&commit=$(commit)&branch=$(branch)");
                json = data, headers = heads)
        dump(r)
    end
end  # module Codecov
