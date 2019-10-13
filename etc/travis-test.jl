using Pkg
Pkg.add(PackageSpec(url = "https://github.com/JuliaCI/CoverageCore.jl", rev = "b2eeba5269fd8784656ad0fe72c5db6cc116bc49"))
Pkg.build()
Pkg.test("Coverage"; coverage=true)
