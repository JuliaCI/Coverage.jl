using Pkg
Pkg.build()
Pkg.test("Coverage"; coverage=true)
