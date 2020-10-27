#=
# Matlab file generation functions
=#

function matlab_main_file()
    file = genfiles.main;
    println(file, "clear;");
    # for using HOMG
    println(file, "import homg.*;");
    println(file, "");
    # These are always included
    println(file, "addpath('operators');");
    println(file, "");
    println(file, "Config;");
    println(file, "Mesh;");
    println(file, "Genfunction;");
    println(file, "Problem;");
    println(file, "Bilinear;");
    println(file, "Linear;");
    println(file, "");
    
    # This should be generated by solve()
    # Just for testing:
    println(file, "u = LHS\\RHS;");
    println(file, "");
    
    # Output should be generated by finalize?
    # Just for testing:
    println(file, "N1d = nelem*config.basis_order_min+1;");
    println(file, "surf(reshape(u,N1d,N1d));");
    println(file, "");
end

function matlab_config_file()
    file = genfiles.config;
    # Duplicate the config struct
    for f in fieldnames(Femshop_config)
        println(file, "config."*string(f)*" = "*matlab_gen_string(getfield(config, f))*";");
    end
    println(file, "order = config.basis_order_min;");
end

function matlab_prob_file()
    file = genfiles.problem;
    # Duplicate the prob struct
    for f in fieldnames(Femshop_prob)
        println(file, "prob."*string(f)*" = "*matlab_gen_string(getfield(prob, f))*";");
    end
end

function matlab_mesh_file()
    file = genfiles.mesh;
    # For using HOMG
    if config.dimension == 1
        nelem = mesh_data.nel;
    elseif config.dimension == 2
        nelem = Int(round(sqrt(mesh_data.nel)));
    elseif config.dimension == 3
        nelem = Int(round(cbrt(mesh_data.nel)));
    end
    println(file, "nelem = "*string(nelem)*";");
    println(file, "mesh = homg.hexmesh(repmat(nelem, 1, config.dimension), @homg.xform.identity);");
    println(file, "bdry = mesh.get_boundary_node_indices(config.basis_order_min);");
end

function matlab_genfunction_file()
    file = genfiles.genfunction;
    for i = 1:length(genfunctions)
        println(file, genfunctions[i].name*"_fun = @(x,y,z,t) ("*genfunctions[i].str*");");
        # Evaluate them at grid points and make them vectors. Make sense???
        println(file, genfunctions[i].name*" = mesh.evaluate("*genfunctions[i].name*"_fun, config.basis_order_min, 'gll');");
    end
    
    # assign variable and coefficient symbols to these vectors
    for v in variables
        println(file, string(v.symbol)*" = '"*string(v.symbol)*"';");
    end
    for v in coefficients
        if typeof(v.value[1]) == GenFunction
            println(file, string(v.symbol)*" = "*v.value[1].name*";");
        else
            println(file, string(v.symbol)*" = "*string(v.value[1])*";");
        end
    end
end

function matlab_bilinear_file(code)
    file = genfiles.bilinear;
    # insert the code part into this skeleton
    content = 
"mesh.set_order(order);
refel = homg.refel ( mesh.dim, order );
dof = prod(mesh.nelems*order + 1);
ne  = prod(mesh.nelems);
NP = (order+1)^mesh.dim;
NPNP = NP * NP;
I = zeros(ne * NPNP, 1);
J = zeros(ne * NPNP, 1);
val = zeros(ne * NPNP, 1);

% loop over elements
for e=1:ne
    pts = mesh.element_nodes(e, refel);
    [detJ, Jac]  = mesh.geometric_factors(refel, pts);
    idx = mesh.get_node_indices (e, order);
    ind1 = repmat(idx,NP,1);
    ind2 = reshape(repmat(idx',NP,1),NPNP,1);
    st = (e-1)*NPNP+1;
    en = e*NPNP;
    I(st:en) = ind1;
    J(st:en) = ind2;\n"*code*"\n
    val(st:en) = elMat(:);
end
LHS = sparse(I,J,val,dof,dof);";
    println(file, content);
    
    # boundary condition
    println(file, "LHS(bdry,:) = 0;");
    println(file, "LHS((size(LHS,1)+1)*(bdry-1)+1) = 1;"); # dirichlet bc
end

function matlab_linear_file(code)
    file = genfiles.linear;
    # insert the code part into this skeleton
    content = 
"mesh.set_order(order);
refel = homg.refel ( mesh.dim, order );
dof = prod(mesh.nelems*order + 1);
ne  = prod(mesh.nelems);
NP = (order+1)^mesh.dim;
NPNP = NP * NP;
RHS = zeros(dof,1);

% loop over elements
for e=1:ne
    pts = mesh.element_nodes(e, refel);
    [detJac, Jac]  = mesh.geometric_factors(refel, pts);
    idx = mesh.get_node_indices (e, order);\n"*code*"\n
    RHS(idx) = elVec;
end
";
    println(file, content);
    
    # boundary condition
    println(file, "RHS(bdry) = prob.bc_func(bdry);"); # dirichlet bc
end

function matlab_stepper_file()
    file = genfiles.stepper;
end
