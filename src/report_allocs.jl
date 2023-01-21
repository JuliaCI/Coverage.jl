# This file is loaded conditionally via @require if PrettyTables is loaded

# import Pkg
import .PrettyTables

function report_allocs(
        io::IO=stdout;
        run_cmd::Union{Nothing, Base.Cmd} = nothing,
        deps_to_monitor::Vector{Module} = Module[],
        dirs_to_monitor::Vector{String} = String[],
        process_filename::Function = process_filename_default,
        is_loading_pkg::Function = (fn, ln) -> false,
        n_rows::Int = 10,
        suppress_url::Bool = true,
    )
    @assert n_rows ≥ 0

    ##### Collect deps
    dep_dirs = map(deps_to_monitor) do dep
        pkgdir(dep)
    end
    all_dirs_to_monitor = [dirs_to_monitor..., dep_dirs...]

    ##### Run representative work & track allocations
    local allocs
    try
        run(run_cmd)
        allocs = analyze_malloc(all_dirs_to_monitor)
    finally

        ##### Clean up files
        for d in all_dirs_to_monitor
            all_files = [
                joinpath(root, f) for
                (root, dirs, files) in Base.Filesystem.walkdir(d) for f in files
            ]
            all_mem_files = filter(x -> endswith(x, ".mem"), all_files)
            for f in all_mem_files
                rm(f)
            end
        end
    end

    ##### Process and plot results
    filter!(x -> x.bytes ≠ 0, allocs)

    # Sometimes module loading takes up huge fraction
    # of allocations, in which case pkg_name is included in the line number
    filter!(x -> !is_loading_pkg(x.filename, x.linenumber), allocs)

    n_alloc_sites = length(allocs)
    if n_alloc_sites == 0
        println(io, "Zero allocations! 🎉")
        return nothing
    end

    all_bytes = reverse(getproperty.(allocs, :bytes))
    all_filenames = reverse(getproperty.(allocs, :filename))
    all_linenumbers = reverse(getproperty.(allocs, :linenumber))
    process_fn(fn) = post_process_fn(process_filename(fn))

    bytes_subset = Int[]
    filenames_subset = String[]
    linenumbers_subset = Int[]
    loc_ids_subset = String[]
    truncated_allocs = false
    for (bytes, filename, linenumber) in zip(all_bytes, all_filenames, all_linenumbers)

        # Sometimes module loading takes up huge fraction
        # of allocations, in which case pkg_name is included in the line number
        is_loading_pkg(filename, linenumber) && continue
        loc_id = "$(process_fn(filename)):$(linenumber)"
        if !(bytes in bytes_subset) && !(loc_id in loc_ids_subset)
            push!(bytes_subset, bytes)
            push!(filenames_subset, filename)
            push!(linenumbers_subset, linenumber)
            push!(loc_ids_subset, loc_id)
            n_rows == 0 && continue
            if length(bytes_subset) ≥ n_rows
                truncated_allocs = true
                break
            end
        end
    end
    sum_bytes = sum(bytes_subset)
    trunc_msg = truncated_allocs ? " (truncated) " : ""
    println(io, "$(length(bytes_subset)) unique allocating sites, $sum_bytes total bytes$trunc_msg")
    xtick_name(filename, linenumber) = "$filename:$linenumber"
    labels = xtick_name.(process_fn.(filenames_subset), linenumbers_subset)

    # TODO: get urls for hypertext
    # pkg_urls = Dict(map(all_dirs_to_monitor) do dep_dir
    #     proj = Pkg.Types.read_project(joinpath(dep_dir, "Project.toml"))
    #     if proj.uuid ≠ nothing
    #         url = Pkg.Operations.find_urls(Pkg.Types.Context().registries, proj.uuid)
    #         Pair(proj.name, url)
    #     else
    #         Pair(proj.name, "https://www.google.com")
    #     end
    # end...)

    fileinfo = map(zip(filenames_subset, linenumbers_subset)) do (filename, linenumber)
        label = xtick_name(process_fn(filename), linenumber)
        if suppress_url
            label
        else
            # TODO: make line number hypertext
            url = ""
            # name = basename(pkg_dir_from_file(dirname(filename)))
            # TODO: incorporate URLS into table
            # if haskey(pkg_urls, name)
            #     url = pkg_urls[name]
            # else
            #     url = "https://www.google.com"
            # end
            PrettyTables.URLTextCell(label, url)
        end
    end

    alloc_percent = map(bytes_subset) do bytes
        alloc_perc = bytes / sum_bytes
        Int(round(alloc_perc*100, digits = 0))
    end
    header = (
        ["<file>:<line number>", "Allocations", "Allocations %"],
        ["", "(bytes)", "(xᵢ/∑x)"],
    )

    table_data = hcat(
        fileinfo,
        bytes_subset,
        alloc_percent,
    )

    PrettyTables.pretty_table(
        io,
        table_data;
        header,
        formatters = PrettyTables.ft_printf("%s", 2:2),
        header_crayon = PrettyTables.crayon"yellow bold",
        subheader_crayon = PrettyTables.crayon"green bold",
        crop = :none,
        alignment = [:l, :c, :c],
    )
end

function post_process_fn(fn)
    # Remove ###.mem.
    fn = join(split(fn, ".jl")[1:(end - 1)], ".jl") * ".jl"
    if startswith(fn, Base.Filesystem.path_separator)
        fn = fn[2:end]
    end
    return fn
end

function process_filename_default(fn)
    # TODO: make this work for Windows
    if occursin(".julia/packages/", fn)
        fn = last(split(fn, ".julia/packages/"))
        pkg_name = first(split(fn, "/"))
        if occursin("$pkg_name/src", fn)
            return fn
        else
            fn = join(split(fn, pkg_name)[2:end], pkg_name)
            sha = split(fn, "/")[2]
            fn = replace(fn, sha*"/" => "")
            fn = pkg_name*fn
            return fn
        end
    end
    return fn
end
