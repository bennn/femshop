#=
# 3D Poisson, Dirichlet bc
# Uses Dendro imported as a custom gen target
=#
if !@isdefined(Femshop)
    include("../Femshop.jl");
    using .Femshop
end
init_femshop("poisson3dcustom");

useLog("poisson3dcustomlog", level=3)

# default values (max_depth=6, wavelet_tol = 0.1, partition_tol = 0.3, solve_tol = 1e-6, max_iters = 100)
generateFor("target_dendro_cg.jl", params=(5, 1, 0.3, 0.000001, 100))

domain(3)
functionSpace(order=1)

u = variable("u")
testSymbol("v")

boundary(u, 1, DIRICHLET, 0)

# Write the weak form 
coefficient("f", "-14*pi*pi*sin(3*pi*x)*sin(2*pi*y)*sin(pi*z)")
weakForm(u, "-dot(grad(u),grad(v)) - f*v")

solve(u);

finalize_femshop()
