#=
# Contains info about all nodes on the domain
=#
struct Grid
    allnodes::Array{Float64}        # All node coordinates
    bdry::Array{Array{Int,1},1}     # Indices of boundary nodes for each BID (bdry[bid][nodes])
    bdryelem::Array{Array{Int,1},1} # Indices of elements touching each BID 
    bids::Array{Int,1}              # BID corresponding to rows of bdrynodes
    loc2glb::Array{Int,2}           # local to global map for each element's nodes
end