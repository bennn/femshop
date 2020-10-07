#=
Module for code generation
=#
module CodeGenerator

export init_codegenerator, finalize_codegenerator, Genfiles,
        generate_main, generate_config, generate_prob, generate_mesh, generate_genfunction, 
        generate_bilinear, generate_linear, generate_stepper, generate_output,
        generate_code_layer

import ..Femshop: JULIA, CPP, MATLAB, SQUARE, IRREGULAR, TREE, UNSTRUCTURED, CG, DG, HDG,
        NODAL, MODAL, LEGENDRE, UNIFORM, GAUSS, LOBATTO, NONLINEAR_NEWTON,
        NONLINEAR_SOMETHING, EULER_EXPLICIT, EULER_IMPLICIT, CRANK_NICHOLSON, RK4, LSRK4,
        ABM4, OURS, PETSC, VTK, RAW_OUTPUT, CUSTOM_OUTPUT, DIRICHLET, NEUMANN, ROBIN,
        MSH_V2, MSH_V4,
        SCALAR, VECTOR, TENSOR, SYM_TENSOR,
        LHS, RHS,
        LINEMESH, QUADMESH, HEXMESH
import ..Femshop: Femshop_config, Femshop_prob, GenFunction, Variable, Coefficient
import ..Femshop: log_entry, printerr
import ..Femshop: config, prob, mesh_data, grid_data, genfunctions, variables, coefficients, test_functions, linears, bilinears, time_stepper
import ..Femshop: CachesimOut

# Holds a set of file streams for generated code
mutable struct Genfiles
    main;       # Runs the computation
    config;     # global configuration
    problem;    # global problem specification
    mesh;       # contains the mesh/grid data
    genfunction;# Generated functions
    bilinear;   # bilinear function: bilinear(args) returns elemental matrix
    linear;     # linear function: linear(args) returns elemental vector
    stepper;    # optional time stepper for time dependent problems
    output;     # output
    
    files;      # an iterable list of these files
    
    Genfiles(m,c,p,n,g,b,l,s,o) = new(m,c,p,n,g,b,l,s,o,[m,c,p,n,g,b,l,s,o]);
end

language = 0;
genDir = "";
genFileName = "";
genFileExtension = "";
commentChar = "";
blockCommentChar = [""; ""];
headerText = "";
genfiles = nothing;

include("generate_code_layer.jl");
include("generate_matlab_utils.jl");
include("generate_homg_files.jl");
include("generate_cpp_utils.jl");
include("generate_dendro_files.jl");

function init_codegenerator(lang, dir, name, header)
    if lang == JULIA
        global genFileExtension = ".jl";
        global commentChar = "#";
        global blockCommentChar = ["#="; "=#"];
        log_entry("Set code generation language to Julia.");
    elseif lang == CPP
        global genFileExtension = ".cpp";
        global commentChar = "//";
        global blockCommentChar = ["/*"; "*/"];
        log_entry("Set code generation language to C++.");
    elseif lang == MATLAB
        global genFileExtension = ".m";
        global commentChar = "%";
        global blockCommentChar = ["%{"; "%}"];
        log_entry("Set code generation language to Matlab.");
    else
        printerr("Invalid language, use JULIA, CPP or MATLAB");
        return nothing;
    end
    
    global language = lang;
    global genDir = dir;
    global genFileName = name;
    global headerText = header;
    
    if language == CPP
        src_dir = genDir*"/src";
        inc_dir = genDir*"/include";
        if !isdir(src_dir)
            mkdir(src_dir);
        end
        if !isdir(inc_dir)
            mkdir(inc_dir);
        end
        m = open(src_dir*"/"*name*genFileExtension, "w");
        c = open(src_dir*"/Config"*genFileExtension, "w");
        p = open(src_dir*"/Problem"*genFileExtension, "w");
        n = open(src_dir*"/Mesh"*genFileExtension, "w");
        g = open(src_dir*"/Genfunction"*genFileExtension, "w");
        b = open(src_dir*"/Bilinear"*genFileExtension, "w");
        l = open(src_dir*"/Linear"*genFileExtension, "w");
        s = open(src_dir*"/Stepper"*genFileExtension, "w");
        o = open(src_dir*"/Output"*genFileExtension, "w");
    elseif language == MATLAB
        m = open(genDir*"/"*name*genFileExtension, "w");
        c = open(genDir*"/Config"*genFileExtension, "w");
        p = open(genDir*"/Problem"*genFileExtension, "w");
        n = open(genDir*"/Mesh"*genFileExtension, "w");
        g = open(genDir*"/Genfunction"*genFileExtension, "w");
        b = open(genDir*"/Bilinear"*genFileExtension, "w");
        l = open(genDir*"/Linear"*genFileExtension, "w");
        s = open(genDir*"/Stepper"*genFileExtension, "w");
        o = open(genDir*"/Output"*genFileExtension, "w");
    end
    
    
    global genfiles = Genfiles(m,c,p,n,g,b,l,s,o);
    
    # write headers
    generate_head(m,headerText);
    generate_head(c,"Configuration info");
    generate_head(p,"Problem info");
    generate_head(n,"Mesh");
    generate_head(g,"Generated functions");
    generate_head(b,"Bilinear term");
    generate_head(l,"Linear term");
    generate_head(s,"Time stepper");
    generate_head(o,"Output");
    
    log_entry("Created code files for: "*name);
    
    return genfiles;
end

function finalize_codegenerator()
    for f in genfiles.files
        close(f);
    end
    log_entry("Closed generated code files.");
end

# Select the generator functions based on language
function generate_main()
    if language == MATLAB
        matlab_main_file();
    elseif language == CPP
        dendro_main_file();
    end
end
function generate_config(params=(5, 1, 0.3, 0.000001, 100))
    if language == MATLAB
        matlab_config_file();
    elseif language == CPP
        dendro_config_file(params); #params has (maxdepth, wavelet_tol, partition_tol, solve_tol, solve_max_iters)
    end
end
function generate_prob()
    if language == MATLAB
        matlab_prob_file();
    elseif language == CPP
        dendro_prob_file();
    end
end
function generate_mesh()
    if language == MATLAB
        matlab_mesh_file();
    elseif language == CPP
        #dendro_mesh_file();
    end
end
function generate_genfunction()
    if language == MATLAB
        matlab_genfunction_file();
    elseif language == CPP
        dendro_genfunction_file();
    end
end
function generate_bilinear(ex)
    if language == MATLAB
        matlab_bilinear_file(ex);
    elseif language == CPP
        dendro_bilinear_file(ex);
    end
end
function generate_linear(ex)
    if language == MATLAB
        matlab_linear_file(ex);
    elseif language == CPP
        dendro_linear_file(ex);
    end
end
function generate_stepper()
    if language == MATLAB
        matlab_stepper_file();
    elseif language == CPP
        #dendro_stepper_file();
    end
end
function generate_output()
    if language == MATLAB
        #matlab_output_file();
    elseif language == CPP
        dendro_output_file();
    end
end
        
# private ###

macro comment(file,line)
    return esc(quote
        println($file, commentChar * $line);
    end)
end

macro commentBlock(file,text)
    return esc(quote
        print($file, "\n"*blockCommentChar[1]*"\n"*text*"\n"*blockCommentChar[2]*"\n");
    end)
end

function generate_head(file, text)
    @comment(file,"This file was generated by Femshop.");
    @commentBlock(file, text);
end

end # module
