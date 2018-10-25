Coverage.jl
===========

*Release version*:

[![Coverage](http://pkg.julialang.org/badges/Coverage_0.6.svg)](http://pkg.julialang.org/?pkg=Coverage)
[![Coverage](http://pkg.julialang.org/badges/Coverage_0.7.svg)](http://pkg.julialang.org/?pkg=Coverage)

*Development version*:

[![Build Status](https://travis-ci.org/JuliaCI/Coverage.jl.svg?branch=master)](https://travis-ci.org/JuliaCI/Coverage.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/ooubhlayk9uek2kr/branch/master?svg=true)](https://ci.appveyor.com/project/ararslan/coverage-jl/branch/master)
[![Coverage Status](https://coveralls.io/repos/github/JuliaCI/Coverage.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaCI/Coverage.jl?branch=master)
[![codecov](https://codecov.io/gh/JuliaCI/Coverage.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaCI/Coverage.jl)

**"Take Julia code coverage and memory allocation results, do useful things with them"**

**Code coverage**: Julia can track how many times, if any, each line of your code is run. This is useful for measuring how much of your code base your tests actually test, and can reveal the parts of your code that are not tested and might be hiding a bug. You can use Coverage.jl to summarize the results of this tracking, or to send them to a service like [Coveralls.io](http://coveralls.io) or [Codecov.io](https://codecov.io/github/JuliaCI).

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
# defaults to src/; alternatively, supply the folder name as argument
coverage = process_folder()
# Get total coverage for all Julia files
covered_lines, total_lines = get_summary(coverage)
# Or process a single file
@show get_summary(process_file("src/MyPkg.jl"))
```
The fraction of total coverage is equal to `covered_lines/total_lines`.

To discover which functions lack testing, browse through the `*.cov` files in your `src/`
directory and look for lines starting with `-` or `0` - those lines were never executed.
Numbers larger than 0 are counts of the number of times the respective line was executed.


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

### LCOV export

There are many tools to work with LCOV info-format files as generated by the `geninfo` tool. Coverage.jl can generate these files:

```julia
coverage = process_folder()
LCOV.writefile("coverage/lcov.info", coverage)
```

### Cleaning up .cov files

When using Coverage.jl locally, over time a lot of `.cov` files can accumulate. Coverage.jl provides the `clean_folder` and `clean_file` methods to either clean up all `.cov` files in a directory (and subdirectories) or only clean the `.cov` files associated with a specific source file.

## Tracking Coverage with [Codecov.io](https://codecov.io)

[Codecov.io](https://codecov.io) is a test coverage tracking tool that integrates with your continuous integration servers (e.g. [TravisCI](https://travis-ci.org/)) or with HTTP POSTs from your very own computer at home.

1. Enable [Codecov.io](https://codecov.io) for your repository. If it is public on GitHub and you are using using TravisCI, this is all you need to do. You can sign into Codecov using your Github identity. You will be served a `REPO_TOKEN`. You'll need this if you're not using a CI solution.
2. Use the command line option when you run your tests
  * Either with something like `julia --code-coverage test/runtests.jl`, or
  * with something like  `julia -e 'Pkg.test("MyPkg", coverage=true)'`
3. Add the following to the end of your `.travis.yml` or `.appveyor.yml` file. This line downloads this package, collects the per-file coverage data, then bundles it up and submits to Codecov. Coverage.jl assumes that the working directory is the package directory, so it changes to that first (so don't forget to replace `MyPkg` with your package's name!
  * On Travis CI:
  ```yml
  after_success:
  - julia -e 'cd(Pkg.dir("MyPkg")); Pkg.add("Coverage"); using Coverage; Codecov.submit(process_folder())'
  ```
  * On AppVeyor:
  ```yml
  after_test:
  - C:\projects\julia\bin\julia -e "cd(Pkg.dir(\"MyPkg\")); Pkg.add(\"Coverage\"); using Coverage; Codecov.submit(process_folder())"
  ```
If you're running coverage on your own machine and want to upload results to Codecov, make a bash script like the following:
```bash
#!/bin/bash
CODECOV_TOKEN=$YOUR_TOKEN_HERE julia -e 'cd(Pkg.dir("MyPkg")); using Coverage; Codecov.submit_local(process_folder())'
```

## Tracking Coverage with [Coveralls.io](https://coveralls.io)

[Coveralls.io](https://coveralls.io) is a test coverage tracking tool that integrates with your continuous integration solution (e.g. [TravisCI](https://travis-ci.org/)).

1. Enable [Coveralls.io](https://coveralls.io) for your repository. If it is public on GitHub and you are using TravisCI, this is all you need to do. If you are using AppVeyor, you need to add a secure environment variable called `REPO_TOKEN` to your `.appveyor.yml` (see [here](https://www.appveyor.com/docs/build-configuration/#secure-variables)). Your repo token can be found in your Coveralls repo settings. If neither of these are true, please submit an issue, and we can work on adding additional functionality for your use case.
2. You must be using `Julia 0.3` or higher, which added the `--code-coverage` command line argument.
3. Use the command line option when you run your tests
  * Either with something like `julia --code-coverage test/runtests.jl`, or
  * with something like  `julia -e 'Pkg.test("MyPkg", coverage=true)'`
4. Add the following to the end of your `.travis.yml` or `.appveyor.yml` file. This line downloads this package, collects the per-file coverage data, then bundles it up and submits to Coveralls. Coverage.jl assumes that the working directory is the package directory, so it changes to that first (so don't forget to replace `MyPkg` with your package's name!
  * On Travis CI:
  ```yml
  after_success:
  - julia -e 'cd(Pkg.dir("MyPkg")); Pkg.add("Coverage"); using Coverage; Coveralls.submit(process_folder())'
  ```
  * On AppVeyor:
  ```yml
  after_test:
  - C:\projects\julia\bin\julia -e "cd(Pkg.dir(\"MyPkg\")); Pkg.add(\"Coverage\"); using Coverage; Coveralls.submit(process_folder())"
  ```


## Julia packages using Coverage.jl

*Pull requests to add your package welcome (or open an issue)*

* [ArgParse.jl](https://github.com/carlobaldassi/ArgParse.jl/blob/master/.travis.yml)
* [AstroLib.jl](https://github.com/giordano/AstroLib.jl/blob/master/.travis.yml)
* [AudioIO.jl](https://github.com/ssfrr/AudioIO.jl/blob/master/.travis.yml)
* [Augur.jl](https://github.com/AugurProject/Augur.jl/blob/master/.travis.yml)
* [Bootstrap.jl](https://github.com/julian-gehring/Bootstrap.jl/blob/master/.travis.yml)
* [CAIRS.jl](https://github.com/scheidan/CAIRS.jl/blob/master/.travis.yml)
* [ClimateTools.jl](https://github.com/Balinus/ClimateTools.jl/blob/master/.travis.yml)
* [DASSL.jl](https://github.com/pwl/DASSL.jl/blob/master/.travis.yml)
* [DataFrames.jl](https://github.com/JuliaStats/DataFrames.jl/blob/master/.travis.yml)
* [Decimals.jl](https://github.com/tensorjack/Decimals.jl/blob/master/.travis.yml)
* [Distributions.jl](https://github.com/JuliaStats/Distributions.jl/blob/master/.travis.yml)
* [DSP.jl](https://github.com/JuliaDSP/DSP.jl/blob/master/.travis.yml)
* [ExtractMacro.jl](https://github.com/carlobaldassi/ExtractMacro.jl/blob/master/.travis.yml)
* [FastaIO.jl](https://github.com/carlobaldassi/FastaIO.jl/blob/master/.travis.yml)
* [FiniteStateMachine.jl](https://github.com/tensorjack/FiniteStateMachine.jl/blob/master/.travis.yml)
* [FourierFlows.jl](https://github.com/FourierFlows/FourierFlows.jl/blob/master/.travis.yml)
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
* [LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl/blob/master/.travis.yml)
* [LinearExpressions.jl](https://github.com/cdsousa/LinearExpressions.jl/blob/master/.travis.yml)
* [Orchestra.jl](https://github.com/svs14/Orchestra.jl/blob/master/.travis.yml)
* [ODE.jl](https://github.com/JuliaLang/ODE.jl/blob/master/.travis.yml)
* [OnlineStats.jl](https://github.com/joshday/OnlineStats.jl/blob/master/.travis.yml)
* [OpenCL.jl](https://github.com/JuliaGPU/OpenCL.jl/blob/master/.travis.yml)
* [OpenStreetMap.jl](https://github.com/tedsteiner/OpenStreetMap.jl/blob/master/.travis.yml)
* [PValueAdjust.jl](https://github.com/dirkschumacher/PValueAdjust.jl/blob/master/.travis.yml)
* [QuantEcon.jl](https://github.com/spencerlyon2/QuantEcon.jl/blob/master/.travis.yml)
* [QuantileRegression.jl](https://github.com/vincentarelbundock/QuantileRegression.jl/blob/master/.travis.yml)
* [RationalSimplex.jl](https://github.com/IainNZ/RationalSimplex.jl/blob/master/.travis.yml)
* [RDF.jl](https://github.com/joejimbo/RDF.jl/blob/master/.travis.yml)
* [Requests.jl](https://github.com/loladiro/Requests.jl/blob/master/.travis.yml)
* [Restful.jl](https://github.com/ylxdzsw/Restful.jl/blob/master/.travis.yml)
* [Robotics.jl](https://github.com/cdsousa/Robotics.jl/blob/master/.travis.yml)
* [RouletteWheels.jl](https://github.com/jbn/RouletteWheels.jl/blob/master/.travis.yml)
* [SASLib.jl](https://github.com/tk3369/SASLib.jl/blob/master/.travis.yml)
* [SimJulia.jl](https://github.com/BenLauwens/SimJulia.jl/blob/master/.travis.yml)
* [SIUnits.jl](https://github.com/loladiro/SIUnits.jl/blob/master/.travis.yml)
* [StatsBase.jl](https://github.com/JuliaStats/StatsBase.jl/blob/master/.travis.yml)
* [TextWrap.jl](https://github.com/carlobaldassi/TextWrap.jl/blob/master/.travis.yml)
* [TimeData.jl](https://github.com/cgroll/TimeData.jl/blob/master/.travis.yml)
* [TypeCheck.jl](https://github.com/astrieanna/TypeCheck.jl/blob/master/.travis.yml)
* [Unitful.jl](https://github.com/ajkeller34/Unitful.jl/blob/master/.travis.yml)
* [URIParser.jl](https://github.com/loladiro/URIParser.jl/blob/master/.travis.yml)
* [URITemplate.jl](https://github.com/loladiro/URITemplate.jl/blob/master/.travis.yml)
* [Voting.jl](https://github.com/tchajed/Voting.jl/blob/master/.travis.yml)
* [WAV.jl](https://github.com/dancasimiro/WAV.jl/blob/master/.travis.yml)
* [Weave.jl](https://github.com/mpastell/Weave.jl/blob/master/.travis.yml)
* [WeightedStats.jl](https://github.com/tensorjack/WeightedStats.jl/blob/master/.travis.yml)
* [YAML.jl](https://github.com/dcjones/YAML.jl)
