#=
Define some constants
Use string values to make printing/interpretation easier
=#
export JULIA, CPP, MATLAB, SQUARE, IRREGULAR, UNIFORM_GRID, TREE, UNSTRUCTURED, CG, DG, HDG,
        NODAL, MODAL, LEGENDRE, UNIFORM, GAUSS, LOBATTO, NONLINEAR_NEWTON,
        NONLINEAR_SOMETHING, EULER_EXPLICIT, EULER_IMPLICIT, CRANK_NICHOLSON, RK4, LSRK4,
        ABM4, OURS, PETSC, VTK, RAW_OUTPUT, CUSTOM_OUTPUT, DIRICHLET, NEUMANN, ROBIN, NO_BC,
        MSH_V2, MSH_V4,
        SCALAR, VECTOR, TENSOR, SYM_TENSOR,
        LHS, RHS,
        LINEMESH, QUADMESH, HEXMESH

# Languages for generated code
const JULIA = "Julia";
const CPP = "C++";
const MATLAB = "Matlab";

# Domain types
const SQUARE = "square";
const IRREGULAR = "irregular";

# Domain decomposition
const UNIFORM_GRID = "uniform grid";
const TREE = "tree";
const UNSTRUCTURED = "unstructured";

# Solver type
const CG = "CG";
const DG = "DG";
const HDG = "HDG";

const NODAL = "nodal";
const MODAL = "modal";

# Function space
const LEGENDRE = "Legendre";

# Element node positions
const UNIFORM = "uniform";
const GAUSS = "Gauss";
const LOBATTO = "Lobatto";

# Nonlinear solver methods
const NONLINEAR_NEWTON = "Newton";
const NONLINEAR_SOMETHING = "something";

# Time steppers
const EULER_EXPLICIT = "Euler-explicit";
const EULER_IMPLICIT = "Euler-implicit";
const CRANK_NICHOLSON = "crank-nicholson";
const RK4 = "RK4";
const LSRK4 = "LSRK4";
const ABM4 = "ABM4";

# Linear system solvers/structures
const OURS = "ours";
const PETSC = "PETSC";

# Output format
const VTK = "vtk";
const RAW_OUTPUT = "raw";
const CUSTOM_OUTPUT = "custom";
# mesh file
const MSH_V2 = "msh-2";
const MSH_V4 = "msh-4";

#BC
const DIRICHLET = "Dirichlet";
const NEUMANN = "Neumann";
const ROBIN = "Robin";
const NO_BC = "No BC";

# variables
const SCALAR = "scalar";
const VECTOR = "vector";
const TENSOR = "tensor";
const SYM_TENSOR = "sym_tensor";

const LHS = "lhs";
const RHS = "rhs";

# simple mesh types
const LINEMESH = "line_mesh";
const QUADMESH = "quad_mesh";
const HEXMESH = "hex_mesh";