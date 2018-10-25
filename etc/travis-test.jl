if VERSION < v"0.7.0"
    Pkg.clone(pwd())
else
    import Pkg
    Pkg.develop(Pkg.PackageSpec(url=pwd()))
end

Pkg.test("Coverage"; coverage=true)
