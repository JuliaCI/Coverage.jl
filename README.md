Coverage.jl
===========

[![Build Status](https://travis-ci.org/IainNZ/Coverage.jl.svg)](https://travis-ci.org/IainNZ/Coverage.jl)
[![Coverage Status](https://coveralls.io/repos/IainNZ/Coverage.jl/badge.png)](https://coveralls.io/r/IainNZ/Coverage.jl)
[![Coverage](http://pkg.julialang.org/badges/Coverage_release.svg)](http://pkg.julialang.org/?pkg=Coverage&ver=release)

**"Take Julia code coverage and memory allocation results, do useful things with them"**

**Code coverage**: Julia can track how many times, if any, each line of your code is run. This is useful for measuring how much of your code base your tests actually test, and can reveal the parts of your code that are not tested and might be hiding a bug. You can use Coverage.jl to summarize the results of this tracking, or to send them to a service like [Coveralls.io](http://coveralls.io).

**Memory allocation**: Julia can track how much memory is allocated by each line of your code. This can reveal problems like type instability, or operations that you might have thought were cheap (in terms of memory allocated) but aren't (i.e. accidental copying).

## Working locally

### Code coverage

*Step 1:* Navigate to your test directory, and start julia like this:
```sh
julia --code-coverage=user
```
or, if you're running Julia 0.4 or higher,
```sh
julia --code-coverage=user --inline=no
```
(Turning off inlining gives substantially more accurate results, but may slow down your tests.)

*Step 2:* Run your tests (e.g., `include("runtests.jl")`) and quit Julia.

*Step 3:* Navigate to the top-level directory of your package, restart Julia (with no special flags) and analyze your code coverage:
```julia
using Coverage
covered_lines, total_lines = coverage_folder()  # defaults to src/; alternatively, supply the folder name as a string
```
The fraction of total coverage is equal to `covered_lines/total_lines`.

> To discover which functions lack testing, browse through the `*.cov` files in your `src/` directory and look for lines starting with `-` or `0` (meaning that those lines never executed; numbers bigger than 0 are counts of the number of times the line executed).

### Memory allocation

Start julia with
```sh
julia --track-allocation=user
```
Then:
- Run whatever commands you wish to test. This first run is to ensure that everything is compiled (because compilation allocates memory).
- Call `clear_malloc_data()` (or, if running julia 0.4 or higher, `Profile.clear_malloc_data()`)
- Run your commands again
- Quit julia

Finally, navigate to the directory holding your source code. Start julia (without command-line flags), and analyze the results using
```julia
using Coverage
analyze_malloc(dirnames)  # could be "." for the current directory, or "src", etc.
```
This will return a vector of `MallocInfo` objects, specifying the number of bytes allocated, the file name, and the line number.
These are sorted in increasing order of allocation size.

## Using Coveralls

[Coveralls.io](https://coveralls.io) is a test-coverage tracking tool that integrates with your continuous integration solution (e.g. [TravisCI](https://travis-ci.org/)).

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
* [Bootstrap.jl](https://github.com/julian-gehring/Bootstrap.jl/blob/master/.travis.yml)
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
* [GraphCentrality.jl](https://github.com/sbromberger/GraphCentrality.jl/blob/master/.travis.yml)
* [GraphLayout.jl](https://github.com/IainNZ/GraphLayout.jl/blob/master/.travis.yml)
* [Homebrew.jl](https://github.com/JuliaLang/Homebrew.jl/blob/master/.travis.yml)
* [HttpParser.jl](https://github.com/JuliaLang/HttpParser.jl/blob/master/.travis.yml)
* [IntervalTrees.jl](https://github.com/BioJulia/IntervalTrees.jl/blob/master/.travis.yml)
* [IPNets.jl](https://github.com/sbromberger/IPNets.jl/blob/master/.travis.yml)
* [JointMoments.jl](https://github.com/tensorjack/JointMoments.jl/blob/master/.travis.yml)
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
* [Voting.jl](https://github.com/tchajed/Voting.jl/blob/master/.travis.yml)
* [WAV.jl](https://github.com/dancasimiro/WAV.jl/blob/master/.travis.yml)
* [Weave.jl](https://github.com/mpastell/Weave.jl/blob/master/.travis.yml)
* [WeightedStats.jl](https://github.com/tensorjack/WeightedStats.jl/blob/master/.travis.yml)
* [YAML.jl](https://github.com/dcjones/YAML.jl)
