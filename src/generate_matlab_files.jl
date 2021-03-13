#=
# Matlab file generation functions
=#

function matlab_main_file()
    file = genfiles.main;
    println(file, "clear;");
    println(file, "");
    # These are always included
    println(file, "");
    println(file, "Utils;");
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
    #println(file, "N1d = sqrt(mesh_data.nel)*config.basis_order_min+1;");
    #println(file, "surf(reshape(u,N1d,N1d));");
    output = "
gxy = grid_data.allnodes';

X = gxy(:,1);
Y = gxy(:,2);

DT = delaunay(gxy);
Tu = triangulation(DT, X, Y, u);

figure();
trisurf(Tu, 'edgecolor', 'none')
view(2);
"
    println(file, output)
    println(file, "");
    
    # Utils file
    matlab_utils_file();
end

function matlab_utils_file()
    utilsfile = open(genDir*"/src/Utils.m", "w");
    
    content = "
classdef Utils
    
    methods(Static)
        % 2D routines
        function y = tensor_IAX (A, x)
            N = size (A, 1);
            y = A * reshape(x, N, N);
            y = y(:);
        end

        function y = tensor_AIX (A, x)
            N = size (A, 1);
            y = A * reshape(x, N, N)';
            y = y'; 
            y = y(:);
        end

        % 3D routines
        function y = tensor_IIAX (A, x)
            N = size (A, 1);
            y = A * reshape(x, N, N*N);
            y = y(:);
        end

        function y = tensor_IAIX (A, x)
            N = size (A, 1);
            q = reshape(x, N, N, N);
            y = zeros(N,N,N);
            for i=1:N
                y(i,:,:) = A * squeeze( q(i,:,:) );
            end
            y = y(:);
        end

        function y = tensor_AIIX (A, x)
            N = size (A, 1);
            y = reshape(x, N*N, N) * A';
            y = y(:);
        end

        function du = tensor_grad(refel, u)
            du = zeros(length(u), refel.dim);
            if (refel.dim == 2)
                du(:,1) = Utils.tensor_IAX (refel.Dr, u);
                du(:,2) = Utils.tensor_AIX (refel.Dr, u);
            else
                du(:,1) = Utils.tensor_IIAX (refel.Dr, u);
                du(:,2) = Utils.tensor_IAIX (refel.Dr, u);
                du(:,3) = Utils.tensor_AIIX (refel.Dr, u);
            end
        end

        function [dx, dy] = tensor_grad2(A, x)
            dx = Utils.tensor_IAX (A, x);
            dy = Utils.tensor_AIX (A, x);
        end

        function [dx, dy, dz] = tensor_grad3(A, x)
            dx = Utils.tensor_IIAX (A, x);
            dy = Utils.tensor_IAIX (A, x);
            dz = Utils.tensor_AIIX (A, x);
        end


        function [J, D] = geometric_factors(refel, pts)

            if (refel.dim == 0)
                xr  = [1];
                J = xr;
            elseif (refel.dim == 1)
                xr  = refel.Dr*pts;
                J = xr;
            elseif (refel.dim == 2)
                if refel.Nfaces == 3 % triangle
                    xr = refel.Ddr*pts(1,:)';
                    xs = refel.Dds*pts(1,:)';
                    yr = refel.Ddr*pts(2,:)';
                    ys = refel.Dds*pts(2,:)';
                    J = -xs.*yr + xr.*ys;
                    J = J(1); 
                else % quad
                    [xr, xs] = Utils.tensor_grad2 (refel.Dg, pts(1,:));
                    [yr, ys] = Utils.tensor_grad2 (refel.Dg, pts(2,:));

                    J = -xs.*yr + xr.*ys;
                end

            else
                [xr, xs, xt] = Utils.tensor_grad3 (refel.Dg, pts(1,:));
                [yr, ys, yt] = Utils.tensor_grad3 (refel.Dg, pts(2,:));
                [zr, zs, zt] = Utils.tensor_grad3 (refel.Dg, pts(3,:));

                J = xr.*(ys.*zt-zs.*yt) - yr.*(xs.*zt-zs.*xt) + zr.*(xs.*yt-ys.*xt);
            end

            if (nargout > 1)
                if (refel.dim == 1)
                    D.rx = 1./J;
                elseif (refel.dim == 2)
                    if refel.Nfaces == 3 % triangle
                        D.rx =  ys./J;
                        D.sx = -yr./J;
                        D.ry = -xs./J;
                        D.sy =  xr./J;
                    else % quad
                        D.rx =  ys./J;
                        D.sx = -yr./J;
                        D.ry = -xs./J;
                        D.sy =  xr./J;
                    end

                else
                    D.rx =  (ys.*zt - zs.*yt)./J;
                    D.ry = -(xs.*zt - zs.*xt)./J;
                    D.rz =  (xs.*yt - ys.*xt)./J;

                    D.sx = -(yr.*zt - zr.*yt)./J;
                    D.sy =  (xr.*zt - zr.*xt)./J;
                    D.sz = -(xr.*yt - yr.*xt)./J;

                    D.tx =  (yr.*zs - zr.*ys)./J;
                    D.ty = -(xr.*zs - zr.*xs)./J;
                    D.tz =  (xr.*ys - yr.*xs)./J;
                end

            end
        end
        
        % pack and unpack variables into a global vector
        % packed vars are in a vector, unpacked are in a cell table
        function pk = pack_vars(upk, pk)
            for i=1:Nvars
                pk(i:Nvars:length(pk)) = upk{i};
            end
        end
        
        function upk = unpack_vars(pk)
            upk = cell(Nvars,1);
            for i=1:Nvars
                upk{i} = pk(i:Nvars:length(pk));
            end
        end
    end
end

"
    println(utilsfile, content);
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

#=
The mesh file contains any code related to setting up the mesh.
The meshdata file contains all of the data from the Refel, MeshData and Grid structs
These are to be read into matlab by a custom matlab function in the mesh file.
=#
function matlab_mesh_file()
    file = genfiles.mesh;
    
    println(file, "f = fopen('MeshData','r');");
    println(file, "% Reference element");
    println(file, matlab_struct_reader("refel", refel));
    println(file, "% mesh data");
    println(file, matlab_struct_reader("mesh_data", mesh_data));
    println(file, "% grid data");
    println(file, matlab_struct_reader("grid_data", grid_data));
    println(file, "fclose(f);");
    
    file = genfiles.meshdata;
    # refel
    write_binary_struct(file, refel);
    # mesh_data
    write_binary_struct(file, mesh_data);
    # grid_data
    write_binary_struct(file, grid_data);
end

function matlab_genfunction_file()
    file = genfiles.genfunction;
    
    for i = 1:length(genfunctions)
        println(file, genfunctions[i].name*"_fun = @(x,y,z,t) ("*genfunctions[i].str*");");
        # Evaluate them at grid points and make them vectors. Make sense???
        println(file, genfunctions[i].name*" = evaluate_genfun("*genfunctions[i].name*"_fun, grid_data.allnodes, 0);");
    end
    
    # assign variable and coefficient symbols to these vectors
    nvars = 0
    for v in variables
        println(file, string(v.symbol)*" = '"*string(v.symbol)*"';");
        nvars += size(v.values,1);
    end
    println(file, "Nvars = " * string(nvars));
    for v in coefficients
        if typeof(v.value[1]) == GenFunction
            println(file, string(v.symbol)*" = "*v.value[1].name*";");
        else
            println(file, string(v.symbol)*" = "*string(v.value[1])*";");
        end
    end
    
    evalgenfun = 
"""
function u = evaluate_genfun(genfun, pts, t)
    n = size(pts,2);
    dim = size(pts,1);
    u = zeros(n,1);
    x = 0;
    y = 0;
    z = 0;
    for i=1:n
        x = pts(1,i);
        if dim > 1
            y = pts(2,i);
            if dim > 2
                z = pts(3,i);
            end
        end
        u(i) = genfun(x,y,z,t);
    end
end
"""
    println(file, evalgenfun);
    
end

function matlab_bilinear_file(code)
    file = genfiles.bilinear;
    # insert the code part into this skeleton
    content = 
"
dof = size(grid_data.allnodes,2);
ne  = mesh_data.nel;
Np = refel.Np;
I = zeros(ne * Np*Np, 1);
J = zeros(ne * Np*Np, 1);
val = zeros(ne * Np*Np, 1);

% loop over elements
for e=1:ne
    idx = grid_data.loc2glb(:,e)\';
    pts = grid_data.allnodes(:,idx);
    [detJ, Jac]  = Utils.geometric_factors(refel, pts);
    
    ind1 = repmat(idx,Np,1);
    ind2 = reshape(repmat(idx',Np,1),Np*Np,1);
    st = (e-1)*Np*Np+1;
    en = e*Np*Np;
    I(st:en) = ind1;
    J(st:en) = ind2;\n"*code*"\n
    val(st:en) = elMat(:);
end
LHS = sparse(I,J,val,dof,dof);";
    println(file, content);
    
    # boundary condition
    println(file, "
for i=1:length(grid_data.bdry)
    LHS(grid_data.bdry{i},:) = 0;
    LHS((size(LHS,1)+1)*(grid_data.bdry{i}-1)+1) = 1;
end"); # dirichlet bc
end

function matlab_linear_file(code)
    file = genfiles.linear;
    # insert the code part into this skeleton
    content = 
"
dof = size(grid_data.allnodes,2);
ne  = mesh_data.nel;
Np = refel.Np;
RHS = zeros(dof,1);

% loop over elements
for e=1:ne
    idx = grid_data.loc2glb(:,e)\';
    pts = grid_data.allnodes(:,idx);
    [detJ, Jac]  = Utils.geometric_factors(refel, pts);
    \n"*code*"\n
    RHS(idx) = elVec;
end
";
    println(file, content);
    
    # boundary condition
    println(file, "
for i=1:length(grid_data.bdry)
    RHS(grid_data.bdry{i}) = prob.bc_func(grid_data.bdry{i});
end"); # dirichlet bc
end

function matlab_stepper_file()
    file = genfiles.stepper;
end
