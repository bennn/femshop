#=
# Linear elasticity
=#

### If the Femshop package has already been added, use this line #########
using Femshop # Note: to add the package, first do: ]add "https://github.com/paralab/femshop.git"

### If not, use these four lines (working from the examples directory) ###
# if !@isdefined(Femshop)
#     include("../Femshop.jl");
#     using .Femshop
# end
##########################################################################

init_femshop("elasticity");

# Optionally generate a log
useLog("elasticitylog")

n = [10,4,4]; # number of elements in x,y,z
interval = [0,1,0,0.2,0,0.2]; # domain bounds

# Set up the configuration (order doesn't matter)
domain(3)                   # dimension
solverType(CG)              # Use CG solver (default)
functionSpace(order=2)      # basis polynomial order
nodeType(LOBATTO)           # GLL elemental node arrangement (default)

# Specify the problem
mesh(HEXMESH, elsperdim=n, bids=4, interval=interval)

u = variable("u", VECTOR)          # make a vector variable with symbol u
testSymbol("v", VECTOR)            # sets the symbol for a test function

boundary(u, 1, DIRICHLET, [0,0,0]) # x=0
boundary(u, 2, NEUMANN, [0,0,0])   # elsewhere
boundary(u, 3, NEUMANN, [0,0,0])
boundary(u, 4, NEUMANN, [0,0,0])

# Write the weak form
coefficient("mu", "x>0.5 ? 0.2 : 10") # discontinuous mu
#coefficient("mu", 1) # constant mu
coefficient("lambda", 1.25)
coefficient("f", ["0","0","-100"], VECTOR)
weakForm(u, "inner( (lambda * div(u) .* [1 0 0; 0 1 0; 0 0 1] + mu .* (grad(u) + transpose(grad(u)))), grad(v)) - dot(f,v)")

println("solving")
solve(u);
println("solved")

# Dump things to the log if desired
log_dump_config();
log_dump_prob();

finalize_femshop() # Finish writing and close any files
