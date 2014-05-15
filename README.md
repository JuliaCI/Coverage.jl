Coverage.jl
===========

[![Build Status](https://travis-ci.org/IainNZ/Coverage.jl.svg)](https://travis-ci.org/IainNZ/Coverage.jl)
[![Coverage Status](https://coveralls.io/repos/IainNZ/Coverage.jl/badge.png)](https://coveralls.io/r/IainNZ/Coverage.jl)

**"Take Julia test coverage results and do useful things with them."**

Right now, that is submitting them to [Coveralls.io](https://coveralls.io), a test-coverage tracking tool that integrates with your continuous integration solution (e.g. [TravisCI](https://travis-ci.org/)).

## Using Coverage.jl with Coveralls.io?

1. Enable [Coveralls.io](https://coveralls.io) for your repository. If it is public on GitHub and you are using using TravisCI, this is all you need to do. If this isn't the case, please submit an issue, and we can work on adding additional functionality for your use case.
2. You must be using `Julia 0.3` or higher, which added the `--code-coverage` commandline argument. If you are testing against Julia 0.2 and 0.3, you will want to put an `if` around some of the following lines - see an [example](https://github.com/JuliaOpt/JuMP.jl/blob/master/.travis.yml) for more detail.
3. Use the commandline option when you run your tests, e.g. `julia --code-coverage test/runtests.jl`.
4. Add the following to the end of your `.travis.yml` file. This line downloads this package, collects the per-file coverage data, then bundles it up and submits to Coveralls. Coverage.jl assumes that the working directory is the package directory, so it changes to that first (so don't forget to replace `MyPackage` with your package's name!
```yml
after_success:
- julia -e 'cd(Pkg.dir("MyPackage")); Pkg.add("Coverage"); using Coverage; Coveralls.submit(Coveralls.process_folder())'
```

If you make it through that, consider adding your package to the list below. Alternatively, if you get stuck see on the examples below or checkout [Coveralls troubleshooting page](https://coveralls.io/docs/troubleshooting).

## Julia packages using Coverage.jl

*Pull requests to add your package welcome (or open an issue)*

* [DataFrames.jl](https://github.com/JuliaStats/DataFrames.jl/blob/master/.travis.yml)
* [Gadfly](https://github.com/dcjones/Gadfly.jl/blob/master/.travis.yml)
* [IntervalTrees.jl](https://github.com/BioJulia/IntervalTrees.jl/blob/master/.travis.yml)
* [JuMP](https://github.com/JuliaOpt/JuMP.jl/blob/master/.travis.yml)
* [ODE.jl](https://github.com/JuliaLang/ODE.jl/blob/master/.travis.yml)
* [RationalSimplex.jl](https://github.com/IainNZ/RationalSimplex.jl/blob/master/.travis.yml)
* [Robotics.jl](https://github.com/cdsousa/Robotics.jl/blob/master/.travis.yml)
* [SIUnits.jl](https://github.com/loladiro/SIUnits.jl/blob/master/.travis.yml)
* [StatsBase.jl](https://github.com/JuliaStats/StatsBase.jl/blob/master/.travis.yml)
* [TimeData.jl](https://github.com/cgroll/TimeData.jl/blob/master/.travis.yml)
* [URIParser.jl](https://github.com/loladiro/URIParser.jl/blob/master/.travis.yml)
* [URITemplate.jl](https://github.com/loladiro/URITemplate.jl/blob/master/.travis.yml)
* [YAML.jl](https://github.com/dcjones/YAML.jl)
