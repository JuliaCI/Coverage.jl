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

After enabling Coveralls.io for your repo, and changing your ``runtests`` line to use the ``--code-coverage`` option, add something like this to the end of your `.travis.yml`:

```yml
after_success:
- julia -e 'cd(Pkg.dir("MyPackage")); Pkg.add("Coverage"); using Coverage; Coveralls.submit(Coveralls.process_folder())'
```

* The line downloads this package, collects the per-file coverage data, then bundles it up and submits to Coveralls. Coverage assumes that the working directory is the package directory, so it changes to that first.

You can see examples [here](https://github.com/JuliaOpt/JuMP.jl/blob/master/.travis.yml) and [here](https://github.com/cdsousa/Robotics.jl/blob/master/.travis.yml)
