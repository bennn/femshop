%This file was generated by Femshop.

%{
This is an example for 2D Poisson, Dirichlet bc.
%}
clear;
import homg.*;

addpath('operators');

Config;
Mesh;
Genfunction;
Problem;
Bilinear;
Linear;

u = LHS\RHS;

N1d = nelem*config.basis_order_min+1;
surf(reshape(u,N1d,N1d));

