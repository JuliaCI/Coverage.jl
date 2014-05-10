Coverage.jl
===========

Take Julia test coverage results and do useful things with them. Right now, that is submitting them to [Coveralls.io](https://coveralls.io) as JSONs.

[![Build Status](https://travis-ci.org/IainNZ/Coverage.jl.svg)](https://travis-ci.org/IainNZ/Coverage.jl)
[![Coverage Status](https://coveralls.io/repos/IainNZ/Coverage.jl/badge.png)](https://coveralls.io/r/IainNZ/Coverage.jl)

## How do I get test coverage results with Julia?

You must be using Julia 0.3 or higher, which added the `--code-coverage` commandline argument. If you do something like

```
julia --code-coverage test/runtests.jl
```

you will find a matching `.cov` file for every `.jl` file run.

## How do I use Coverage.jl to get automated test coverage results submitted to Coveralls.io?

After enabling Coveralls.io for your repo, add something like this to your `.travis.yml`:

```
- julia --code-coverage test/runtests.jl
- julia -e 'cd(Pkg.dir("MyPackage")); Pkg.add("Coverage"); using Coverage; Coveralls.submit(Coveralls.process_folder())'
```

* The first line says to run the tests with the code-coverage option enabled.
* The second line downloads this package, collects the per-file coverage data, then bundles it up and submits to Coveralls. It assumes that the working directory is the package directory.
