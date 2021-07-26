########################################################
# Utility functions used by the various code generators
########################################################

# Checks if the coefficient has constant value.
# If so, also returns the value.
function is_constant_coef(c)
    isit = false;
    val = 0;
    for i=1:length(coefficients)
        if c === coefficients[i].symbol
            isit = (typeof(coefficients[i].value[1]) <: Number);
            if isit
                val = coefficients[i].value[1];
            else
                val = coefficients[i].value[1].name;
            end
        end
    end
    
    return (isit, val);
end

# Checks the type of coefficient: constant, genfunction, or variable
# Returns: (type, val)
# special: type=-1, val=0
# number: type=0, val=number
# constant coef: type=1, val=number
# genfunction: type=2, val= index in genfunctions array
# variable: type=3, val=index in variables array
function get_coef_val(c)
    if c.index == -1
        # It is a special symbol like dt
        return (-1, 0);
    elseif c.index == 0
        # It is a number
        return(0, c.name);
    end
    
    type = 0;
    val = 0;
    for i=1:length(coefficients)
        if c.name == string(coefficients[i].symbol)
            isit = (typeof(coefficients[i].value[c.index]) <: Number);
            if isit
                type = 1; # a constant wrapped in a coefficient ... not ideal
                val = coefficients[i].value[c.index];
            else
                type = 2; # a function
                name = coefficients[i].value[c.index].name;
                for j=1:length(genfunctions)
                    if name == genfunctions[j].name
                        val = j;
                    end
                end
            end
        end
    end
    if type == 0 # a variable
        for i=1:length(variables)
            if c.name == string(variables[i].symbol)
                type = 3;
                val = variables[i].index;
            end
        end
    end
    if type == 0 # something special with a nonzero index
        return (-1,0);
    end
    
    return (type, val);
end

# Returns the index in femshop's coefficient array
# or -1 if it is not there.
function get_coef_index(c)
    ind = -1;
    for i=1:length(coefficients)
        if c.name == string(coefficients[i].symbol)
            ind = coefficients[i].index;
        end
    end
    
    return ind;
end

# Makes a name for this value based on coefficient or variable name, derivative and other modifiers, and component index.
function make_coef_name(c)
    # Special case for dt or other special symbols
    if c.index < 0
        return c.name;
    end
    
    tag = "";
    for i=1:length(c.flags)
        tag = c.flags[i] * tag;
    end
    for i=1:length(c.derivs)
        tag = "D"*string(c.derivs[i]) * tag;
    end
    
    str = "coef_"*tag*"_"*string(c.name)*"_"*string(c.index);
    
    return str;
end

function is_test_function(ent)
    for t in test_functions
        if string(t.symbol) == ent.name
            return true;
        end
    end
    return false;
end

function is_unknown_var(ent, vars)
    if typeof(vars) == Variable
        return ent.name == string(vars.symbol);
    elseif typeof(vars) <:Array
        for v in vars
            if string(v.symbol) == ent.name
                return true;
            end
        end
    end
    return false;
end

# They are the same if all parts of them are the same.
function is_same_entity(a, b)
    return a.name == b.name && a.index == b.index && a.derivs == b.derivs && a.flags == b.flags;
end

# Replaces math operators with broadcast(dot) versions
function broadcast_all_ops(ex)
    if typeof(ex) <: Array
        result = [];
        for i=1:length(ex)
            push!(result, broadcast_all_ops(ex[i]));
        end
        return result;
        
    elseif typeof(ex) == Expr
        if ex.head === :call
            bopped = false;
            if ex.args[1] === :^ ex.args[1] = :.^
            elseif ex.args[1] === :/ ex.args[1] = :./
            elseif ex.args[1] === :* ex.args[1] = :.*
            elseif ex.args[1] === :+ ex.args[1] = :.+
            elseif ex.args[1] === :- ex.args[1] = :.-
            elseif ex.args[1] in [:.+, :.-, :.*, :./, :.^] # no change
            else # named operator: abs -> abs.
                argtuple = Expr(:tuple, ex.args[2]);
                if length(ex.args) > 2
                    append!(argtuple.args, ex.args[3:end]);
                end
                bop = Expr(:., ex.args[1], argtuple);
                ex = bop;
                bopped = true;
            end
            if bopped
                for i=1:length(ex.args[2].args)
                    ex.args[2].args[i] = broadcast_all_ops(ex.args[2].args[i]);
                end
            else
                for i=2:length(ex.args)
                    ex.args[i] = broadcast_all_ops(ex.args[i]);
                end
            end
        end
        
        return ex;
        
    elseif typeof(ex) == Symbol
        # replace ^,/,+,- with .^,./,.+,.-
        if ex === :^ ex = :.^
        elseif ex === :/ ex = :./
        elseif ex === :* ex = :.*
        elseif ex === :+ ex = :.+
        elseif ex === :- ex = :.-
        end
    else
        return ex;
    end
end

# symex could be an array. If so, make a similar array containing an array of terms.
# This does any final processing of the terms. At this point symex should be a single term 
# without a top level + or -. for example, a*b/c or a^2*b but not a*b+c
# What processing is done:
#   a/b -> a*(1/b)
#   Broadcast all ops: +-*/^ -> .+.-.*./.^
#   If it's a SymExpression, return the proccessed Expr in symex.tree
function process_terms(symex)
    if typeof(symex) <: Array
        terms = [];
        for i=1:length(symex)
            push!(terms, process_terms(symex[i]));
        end
        
    else
        if typeof(symex) == SymExpression
            newex = copy(symex.tree);
        elseif typeof(symex) == Expr
            newex = copy(symex);
        else
            newex = symex;
        end
        
        #println(string(newex) * " : " * string(typeof(newex)))
        
        if typeof(newex) == Expr && newex.head === :call
            if (newex.args[1] === :+ || newex.args[1] === :.+ || newex.args[1] === :- || newex.args[1] === :.-)
                println("unexpected term in process terms: "*string(newex));
            else
                if newex.args[1] === :/ || newex.args[1] === :./
                    # change a/b to a*1/b
                    mulex = :(a.*b);
                    mulex.args[2] = newex.args[2];
                    newex.args[2] = 1;
                    mulex.args[3] = newex;
                    newex = mulex;
                end
            end
            
            # broadcast ops
            newex = broadcast_all_ops(newex);
            
            terms = newex;
        else
            # There is just one factor
            terms = newex;
        end
    end
    
    return terms;
end

# Assume the term looks like a*b*c or a*(b*c) or something similar.
function separate_factors(ex, var=nothing)
    test_part = nothing;
    trial_part = nothing;
    coef_part = nothing;
    test_ind = 0;
    trial_ind = 0;
    
    if typeof(ex) == Expr
        if (ex.args[1] === :.- || ex.args[1] === :-) && length(ex.args)==2
            # a negative sign. Stick it on one of the factors
            (test_part, trial_part, coef_part, test_ind, trial_ind) = separate_factors(ex.args[2], var);
            negex = :(-a);
            if !(coef_part === nothing)
                negex.args[2] = coef_part;
                coef_part = negex;
            elseif !(test_part === nothing)
                negex.args[2] = test_part;
                test_part = negex;
            elseif !(trial_part === nothing)
                negex.args[2] = trial_part;
                trial_part = negex;
            end
            
        elseif ex.args[1] === :.* || ex.args[1] === :*
            tmpcoef = [];
            # Recursively separate each arg to handle a*(b*(c*...))
            for i=2:length(ex.args)
                (testi, triali, coefi, testindi, trialindi) = separate_factors(ex.args[i], var);
                if !(testi === nothing)
                    test_part = testi;
                    test_ind = testindi;
                end
                if !(triali === nothing)
                    trial_part = triali;
                    trial_ind = trialindi;
                end
                if !(coefi === nothing)
                    push!(tmpcoef, coefi);
                end
            end
            if length(tmpcoef) > 1
                coef_part = :(a.*b);
                coef_part.args = [:.*];
                append!(coef_part.args, tmpcoef);
            elseif length(tmpcoef) == 1
                coef_part = tmpcoef[1];
            end
            
        else # It is an Expr, but not -() or * (note: at this point a/b is a*(1/b) )
            # This simplification may cause trouble somewhere. Revisit if needed.
            coef_part = ex;
        end
    elseif typeof(ex) == SymEntity
        if is_test_function(ex)
            test_part = ex;
            test_ind = ex.index;
        elseif !(var === nothing) && is_unknown_var(ex, var)
            trial_part = ex;
            # find the trial index
            if typeof(var) <: Array
                tmpind = 0;
                for vi=1:length(var)
                    if is_unknown_var(ex,var[vi])
                        trial_ind = tmpind + ex.index;
                    else
                        tmpind += length(var[vi].symvar);
                    end
                end
            else
                trial_ind = ex.index;
            end
        else
            coef_part = ex;
        end
    else # a number?
        coef_part = ex;
    end
    
    # println(ex)
    # println(test_part)
    # println(trial_part)
    # println(coef_part)
    # println("")
    
    return (test_part, trial_part, coef_part, test_ind, trial_ind);
end

function replace_entities_with_symbols(ex)
    if typeof(ex) <: Array
        for i=1:length(ex)
            ex[i] = replace_entities_with_symbols(ex[i]);
        end
    elseif typeof(ex) == Expr
        for i=1:length(ex.args)
            ex.args[i] = replace_entities_with_symbols(ex.args[i]);
        end
    elseif typeof(ex) == SymEntity
        # use make_coef_name
        return Symbol(make_coef_name(ex));
    end
    
    return ex;
end

# Searches for any of the specified ents(strings matching entity.name) and adds a flag to entity.flags
function apply_flag_to_entities(ex, ents, flag)
    if typeof(ex) == Expr
        for i=1:length(ex.args)
            ex.args[i] = apply_flag_to_entities(ex, ents, flag);
        end
        
    elseif typeof(ex) == SymEntity
        if ex.name in ents
            push!(ex.flags, flag);
        end
    end
    
    return ex;
end

# Traverses the Expr replacing a specific symbol
function replace_specific_symbol(ex, old_symbol, new_symbol)
    if typeof(ex) == Expr
        for i=1:length(ex.args)
            ex.args[i] = replace_specific_symbol(ex.args[i], old_symbol, new_symbol);
        end
        
    elseif typeof(ex) == Symbol
        if ex === old_symbol
            return new_symbol;
        end
    end
    
    return ex;
end

# Turns the generated code string into an Expr block to be put in a generated function.
function code_string_to_expr(s)
    e = Expr(:block);
    lines = split(s, "\n", keepempty=false);
    
    skiplines = 0;
    for i=1:length(lines)
        if skiplines > 0
            skiplines = skiplines-1;
            continue;
        end
        # if blocks are split across several lines. Join them
        if occursin(" if ", split(lines[i], "#")[1])
            level = 1;
            ifline = lines[i];
            j = i+1;
            while j <= length(lines)
                ifline = ifline * "\n" * lines[j];
                if occursin(" if ", split(lines[j], "#")[1])
                    level = level + 1;
                end
                if occursin("end", split(lines[j], "#")[1])
                    level = level - 1;
                end
                if level == 0
                    # The end of the top level if
                    skiplines = skiplines + j - i;
                    break;
                end
                j=j+1;
            end
            tmp = Meta.parse(ifline);
            
        else
            tmp = Meta.parse(lines[i]);
        end
        
        # a toplevel wrapper might be put around the expression. remove it.
        if !(tmp === nothing)
            if tmp.head === :toplevel
                if length(tmp.args) > 0
                    tmp = tmp.args[1];
                else
                    tmp = nothing;
                end
            end
        end
        if !(tmp === nothing)
            push!(e.args, tmp);
        end
    end
    
    return e;
end