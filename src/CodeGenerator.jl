#=
Module for code generation
=#
module CodeGenerator

export init_code_generator, finalize_code_generator, set_generation_target,
        generate_all_files, add_generated_file,
        # generate_main, generate_config, generate_prob, generate_mesh, generate_genfunction, 
        # generate_bilinear, generate_linear, generate_stepper, generate_output,
        generate_code_layer, generate_assembly_loops
        #, generate_code_layer_surface, generate_code_layer_fv

import ..Femshop: JULIA, CPP, MATLAB, DENDRO, HOMG, CUSTOM_GEN_TARGET,
            SQUARE, IRREGULAR, UNIFORM_GRID, TREE, UNSTRUCTURED, 
            CG, DG, HDG, FV,
            NODAL, MODAL, CELL, LEGENDRE, UNIFORM, GAUSS, LOBATTO, 
            NONLINEAR_NEWTON, NONLINEAR_SOMETHING, 
            EULER_EXPLICIT, EULER_IMPLICIT, CRANK_NICHOLSON, RK4, LSRK4, ABM4, 
            DEFAULT_SOLVER, PETSC, 
            VTK, RAW_OUTPUT, CUSTOM_OUTPUT, 
            DIRICHLET, NEUMANN, ROBIN, NO_BC, FLUX,
            MSH_V2, MSH_V4,
            SCALAR, VECTOR, TENSOR, SYM_TENSOR, VAR_ARRAY,
            LHS, RHS,
            LINEMESH, QUADMESH, HEXMESH
import ..Femshop: Femshop_config, Femshop_prob, GenFunction, Variable, Coefficient
import ..Femshop: log_entry, printerr
import ..Femshop: config, prob, refel, mesh_data, grid_data, genfunctions, variables, coefficients, 
        test_functions, linears, bilinears, indexers, time_stepper, language, gen_framework
import ..Femshop: SymExpression, SymEntity
import ..Femshop: CachesimOut, use_cachesim
import ..Femshop: custom_gen_funcs

genDir = "";
genFileName = "";
gen_file_extension = "";
comment_char = "";
block_comment_char = [""; ""];
headerText = "";
genfiles = [];
external_get_language_elements_function = nothing;
external_generate_code_layer_function = nothing;
external_generate_code_files_function = nothing;

# for custom targets
using_custom_target = false;
# Temporary placeholders for external code gen functions that must be provided.
# These are reassigned in set_custom_target()
function default_language_elements_function() return (".jl", "#", ["#=", "=#"]) end;
function default_code_layer_function(var, entities, terms, lorr, vors) return ("","") end;
function default_code_files_function(var, lhs_vol, lhs_surf, rhs_vol, rhs_surf) return 0 end;

# general code generator functions
include("code_generator_utils.jl");
include("generate_code_layer.jl");

# code gen functions for each solver type and target
include("generate_code_layer_cg_julia.jl");
include("generate_code_layer_dg_julia.jl");
include("generate_code_layer_fv_julia.jl");

# # target specific code gen functions
# include("generate_code_layer_dendro.jl");
# include("generate_code_layer_homg.jl");
# include("generate_code_layer_matlab.jl");
# include("generate_code_layer_cachesim.jl");

# Surface integrals should be handled in the same place TODO
#include("generate_code_layer_surface.jl");

#Matlab
# include("generate_matlab_utils.jl");
# include("generate_matlab_files.jl");
# include("generate_homg_files.jl");
# #C++
# include("generate_cpp_utils.jl");
# include("generate_dendro_files.jl");


#### Note
# default Dendro parameters
# parameters = (5, 1, 0.3, 0.000001, 100);#(maxdepth, wavelet_tol, partition_tol, solve_tol, solve_max_iters)
####

function init_code_generator(dir, name, header)
    global gen_file_extension = ".jl";
    global comment_char = "#";
    global block_comment_char = ["#="; "=#"];
    global genDir = dir;
    global genFileName = name;
    global headerText = header;
    
    global external_get_language_elements_function = default_language_elements_function;
    global external_generate_code_layer_function = default_code_layer_function;
    global external_generate_code_files_function = default_code_files_function;
end

# Sets the functions to be used during external code generation
function set_generation_target(lang_elements, code_layer, file_maker)
    global external_get_language_elements_function = lang_elements;
    global external_generate_code_layer_function = code_layer;
    global external_generate_code_files_function = file_maker;
    global using_custom_target = true;
    global gen_file_extension;
    global comment_char;
    global block_comment_char;
    (gen_file_extension, comment_char, block_comment_char) = Base.invokelatest(external_get_language_elements_function);
end

function add_generated_file(filename; dir="", make_header_text=true)
    if length(dir) > 0
        code_dir = genDir*"/"*dir;
        if !isdir(code_dir)
            mkdir(code_dir);
        end
    else
        code_dir = genDir;
    end
    newfile = open(code_dir*"/"*filename, "w");
    push!(genfiles, newfile);
    if make_header_text
        generate_head(newfile, headerText);
    end
    
    return newfile;
end

function generate_all_files(var, lhs_vol, lhs_surf, rhs_vol, rhs_surf; parameters=0)
    if using_custom_target
        external_generate_code_files_function(var, lhs_vol, lhs_surf, rhs_vol, rhs_surf);
    end
end

function finalize_code_generator()
    for f in genfiles
        close(f);
    end
    log_entry("Closed generated code files.");
end

#### Utilities ####

function comment(file,line)
    println(file, comment_char * line);
end

function commentBlock(file,text)
    print(file, "\n"*block_comment_char[1]*"\n"*text*"\n"*block_comment_char[2]*"\n");
end

function generate_head(file, text)
    comment(file,"This file was generated by Femshop.");
    commentBlock(file, text);
end

# for writing structs to binary files
# format is | number of structs[Int64] | sizes of structs[Int64*num] | structs |
function write_binary_head(f, num, szs)
    Nbytes = 0;
    write(f, num);
    Nbytes += sizeof(num)
    for i=1:length(szs)
        write(f, szs[i])
        Nbytes += sizeof(szs[i])
    end
    return Nbytes;
end

# Write an array to a binary file.
# Return number of bytes written.
function write_binary_array(f, a)
    Nbytes = 0;
    for i=1:length(a)
        if isbits(a[i])
            write(f, a[i]);
            Nbytes += sizeof(a[i]);
        else
            Nbytes += write_binary_array(f,a[i]);
        end
    end
    return Nbytes;
end

# Assumes that the struct only has isbits->true types or arrays.
# Returns number of bytes written.
function write_binary_struct(f, s)
    Nbytes = 0;
    for fn in fieldnames(typeof(s))
        comp = getfield(s, fn);
        if isbits(comp)
            write(f, comp);
            Nbytes += sizeof(comp)
        else
            Nbytes += write_binary_array(f,comp);
        end
    end
    return Nbytes;
end

end # module