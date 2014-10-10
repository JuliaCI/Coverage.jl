Coverage.jl
===========

[![Build Status](https://travis-ci.org/IainNZ/Coverage.jl.svg)](https://travis-ci.org/IainNZ/Coverage.jl)
[![Coverage Status](https://coveralls.io/repos/IainNZ/Coverage.jl/badge.png)](https://coveralls.io/r/IainNZ/Coverage.jl)

**"Take Julia test coverage results and do useful things with them."**

Right now, that is submitting them to [Coveralls.io](https://coveralls.io), a test-coverage tracking tool that integrates with your continuous integration solution (e.g. [TravisCI](https://travis-ci.org/)).

## Using Coverage.jl with Coveralls.io?

1. Enable [Coveralls.io](https://coveralls.io) for your repository. If it is public on GitHub and you are using using TravisCI, this is all you need to do. If this isn't the case, please submit an issue, and we can work on adding additional functionality for your use case.
2. You must be using `Julia 0.3` or higher, which added the `--code-coverage` command line argument.
3. Use the command line option when you run your tests
  * Either with something like `julia --code-coverage test/runtests.jl`, or
  * with something like  `julia -e 'Pkg.test("MyPkg", coverage=true)'`
4. Add the following to the end of your `.travis.yml` file. This line downloads this package, collects the per-file coverage data, then bundles it up and submits to Coveralls. Coverage.jl assumes that the working directory is the package directory, so it changes to that first (so don't forget to replace `MyPkg` with your package's name!
```yml
after_success:
- julia -e 'cd(Pkg.dir("MyPkg")); Pkg.add("Coverage"); using Coverage; Coveralls.submit(Coveralls.process_folder())'
```

If you make it through that, consider adding your package to the list below. Alternatively, if you get stuck see on the examples below or checkout [Coveralls troubleshooting page](https://coveralls.io/docs/troubleshooting).

## Julia packages using Coverage.jl

*Pull requests to add your package welcome (or open an issue)*

* [ArgParse.jl](https://github.com/carlobaldassi/ArgParse.jl/blob/master/.travis.yml)
* [AudioIO.jl](https://github.com/ssfrr/AudioIO.jl/blob/master/.travis.yml)
* [CAIRS.jl](https://github.com/scheidan/CAIRS.jl/blob/master/.travis.yml)
* [DASSL.jl](https://github.com/pwl/DASSL.jl/blob/master/.travis.yml)
* [DataFrames.jl](https://github.com/JuliaStats/DataFrames.jl/blob/master/.travis.yml)
* [Decimals.jl](https://github.com/tensorjack/Decimals.jl/blob/master/.travis.yml)
* [Distributions.jl](https://github.com/JuliaStats/Distributions.jl/blob/master/.travis.yml)
* [DSP.jl](https://github.com/JuliaDSP/DSP.jl/blob/master/.travis.yml)
* [FastaIO.jl](https://github.com/carlobaldassi/FastaIO.jl/blob/master/.travis.yml)
* [FiniteStateMachine.jl](https://github.com/tensorjack/FiniteStateMachine.jl/blob/master/.travis.yml)
* [Gadfly.jl](https://github.com/dcjones/Gadfly.jl/blob/master/.travis.yml)
* [GeometricalPredicates.jl](https://github.com/skariel/GeometricalPredicates.jl/blob/master/.travis.yml)
* [Glob.jl](https://github.com/vtjnash/Glob.jl/blob/master/.travis.yml)
* [GradientBoost.jl](https://github.com/svs14/GradientBoost.jl/blob/master/.travis.yml)
* [GraphLayout.jl](https://github.com/IainNZ/GraphLayout.jl/blob/master/.travis.yml)
* [Homebrew.jl](https://github.com/JuliaLang/Homebrew.jl/blob/master/.travis.yml)
* [HttpParser.jl](https://github.com/JuliaLang/HttpParser.jl/blob/master/.travis.yml)
* [IntervalTrees.jl](https://github.com/BioJulia/IntervalTrees.jl/blob/master/.travis.yml)
* [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl/blob/master/.travis.yml)
* [LibGit2.jl](https://github.com/jakebolewski/LibGit2.jl/blob/master/.travis.yml)
* [LinearExpressions.jl](https://github.com/cdsousa/LinearExpressions.jl/blob/master/.travis.yml)
* [Orchestra.jl](https://github.com/svs14/Orchestra.jl/blob/master/.travis.yml)
* [ODE.jl](https://github.com/JuliaLang/ODE.jl/blob/master/.travis.yml)
* [OpenCL.jl](https://github.com/JuliaGPU/OpenCL.jl/blob/master/.travis.yml)
* [OpenStreetMap.jl](https://github.com/tedsteiner/OpenStreetMap.jl/blob/master/.travis.yml)
* [PValueAdjust.jl](https://github.com/dirkschumacher/PValueAdjust.jl/blob/master/.travis.yml)
* [QuantEcon.jl](https://github.com/spencerlyon2/QuantEcon.jl/blob/master/.travis.yml)
* [RationalSimplex.jl](https://github.com/IainNZ/RationalSimplex.jl/blob/master/.travis.yml)
* [RDF.jl](https://github.com/joejimbo/RDF.jl/blob/master/.travis.yml)
* [Requests.jl](https://github.com/loladiro/Requests.jl/blob/master/.travis.yml)
* [Robotics.jl](https://github.com/cdsousa/Robotics.jl/blob/master/.travis.yml)
* [SIUnits.jl](https://github.com/loladiro/SIUnits.jl/blob/master/.travis.yml)
* [StatsBase.jl](https://github.com/JuliaStats/StatsBase.jl/blob/master/.travis.yml)
* [TextWrap.jl](https://github.com/carlobaldassi/TextWrap.jl/blob/master/.travis.yml)
* [TimeData.jl](https://github.com/cgroll/TimeData.jl/blob/master/.travis.yml)
* [TypeCheck.jl](https://github.com/astrieanna/TypeCheck.jl/blob/master/.travis.yml)
* [URIParser.jl](https://github.com/loladiro/URIParser.jl/blob/master/.travis.yml)
* [URITemplate.jl](https://github.com/loladiro/URITemplate.jl/blob/master/.travis.yml)
* [WeightedStats.jl](https://github.com/tensorjack/WeightedStats.jl/blob/master/.travis.yml)
* [YAML.jl](https://github.com/dcjones/YAML.jl)
