#export nonlinear

mutable struct nonlinear
    jac;       # The Jacobian matrix
    res;       # The residual vector
    var;     # The solution veltor
    max_iter;         # max iteration
    atol;
	rtol;
	bilinear;
	linear;
    nonlinear(max_iter, atol, rtol) = new(0,0,0,max_iter, atol, rtol,0,0);
end

function init_nonlinear(nl,x,bi,li);
	nl.var = x;
	nl.bilinear = bi;
	nl.linear = li;
end

function eval_jac(nl, formjac)
	 (nl.jac, b) = formjac(nl.var, nl.bilinear, nl.linear);
end

function eval_res(nl, formfunc)
	(A, b) = formfunc(nl.var, nl.bilinear, nl.linear);
	nl.res = b;#A*nl.var.values - b;
	#@show b;
end

function newton(nl,formjac, formfunc)
	eval_res(nl, formfunc);
	init_res = norm(nl.res);
	if (init_res < nl.atol)
		print("\ninitial residual = ", init_res, ", already converged\n");
		return;
	end
	print("\ninitial residual = ", init_res, "\n");

	i = 0;
	while (i < nl.max_iter)
		eval_jac(nl, formjac);
		delta = - nl.jac \ nl.res;
		#@show delta	
		# place the values in the variable value arrays

		#print("\nlength(nl.var) = ", length(nl.var), "\n");
		#@show nl.var[1].values;
		#@show nl.var[2].values;
		
		if typeof(nl.var) <: Array
			for vi=1:1 #length(nl.var)
				components = length(nl.var[vi].symvar.vals);
				for compi=1:components
					nl.var[vi].values[:,compi] = nl.var[vi].values[:,compi]+delta[:];
				end
			end
		else
			print("\nHERE\n");
			components = length(nl.var.symvar.vals);
			print("\ncomponents = ", components, "\n");
			print("\nsymvar = ", nl.var.symvar, "\n");
			print("\nvals = ", nl.var.symvar.vals, "\n");
			for compi=1:components
				nl.var.values[:,compi] =  nl.var.values[:,compi]+delta[compi:components:end];
			end
		end

		i = i+1;
		eval_res(nl, formfunc);
		curr_res = norm(nl.res);
		print(i,"th iteration residual = ", curr_res, "\n");
		if (curr_res < nl.atol || curr_res/init_res < nl.rtol)
			print("\nsolution is converged in ", i, " iterations\n");
			return;
		end
	end
	print("\nsolution is not converged\n");
end
