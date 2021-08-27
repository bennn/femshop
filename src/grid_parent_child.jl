#=
Subdivide each element in the grid into several children, making a structured parent/child relation.
This is for higher order FV use.
Important: Since this is for FV, only first order elements should be used. Only vertex nodes will be 
considered and the resulting grid will only have vertex nodes.
=#

# Struct for keeping the parent info.
struct ParentMaps
    child2parent::Array{Int,2}     # size = (2, allChildren) 1 = index of parent, 2 = location within parent
    parent2child::Array{Int,2}     # size = (myChildren, allParents) global index of each child in each parent
    parent2face::Array{Int,2}      # size = (myFaces, allParents) global index of each face in each parent
    parent2neighbor::Array{Int,2}  # size = (outerFaces, allParents) index of neighboring parents
    
    patches::Array{Int, 2}         # size = (outerfaces*neighborChildren) local patch around each parent
end

# Divides all elements in a grid
function divide_parent_grid(grid, order)
    # The convention for n numbers is: N->global, n->local
    dim = size(grid.allnodes,1);
    Nparent = size(grid.glbvertex,2);
    nvertex = size(grid.glbvertex,1); # number of vertices for each element assuming one element type.
    nneighbor = size(grid.element2face,1);
    Npnodes = size(grid.allnodes,2);
    Npfaces = size(grid.face2element,2);
    nbids = length(grid.bdry);
    nchildren = 0; # will be set below
    
    if order < 2
        #nothing needs to happen to the grid, but we should make the maps anyway
        c2p = ones(2, Nparent);
        c2p[1,:] = 1:Nparent;
        p2c = Array(1:Nparent)';
        p2f = grid.element2face;
        p2n = zeros(nneighbor, Nparent);
        for i=1:Nparent
            for j=1:nneighbor
                fid = grid.element2face[j,i];
                if grid.face2element[1,fid] == i
                    p2n[j,i] = grid.face2element[2,fid];
                else
                    p2n[j,i] = grid.face2element[1,fid];
                end
            end
        end
        
        parent_maps = ParentMaps(c2p, p2c, p2f, p2n);
        return (parent_maps, grid);
    end
    
    if dim==1
        level = order-1;
        nchildren = 1 + level;
        nfaces = 2 + level;
        Ncnodes = Nparent * nchildren + 1;
        Ncfaces = Npfaces + level*Nparent;
        ncvertex = 2;
        nfacevertex = 1;
        nfaceperchild = 2;
        cfaceperpface = 1;
    elseif dim==2
        if order > 6
            printerr("Orders greater then 6 are not ready for 2D FV. Changing to 6.")
            order = 6;
        end
        nchildren = 4; # same for triangles and quads
        if nvertex==3 # triangle
            nfaces = 9;
            Ncnodes = Npnodes + Npfaces; # add one node per face
            Ncfaces = Npfaces*2 + Nparent*3; # each parent face becomes 2, plus 3 internal
            ncvertex = 3;
            nfacevertex = 2;
            nfaceperchild = 3;
            cfaceperpface = 2;
        elseif nvertex==4 # quad
            nfaces = 12;
            Ncnodes = Npnodes + Npfaces + Nparent; # add one per face plus one per parent(center)
            Ncfaces = Npfaces*2 + Nparent*4; # each parent face becomes 2, plus 4 internal
            ncvertex = 4;
            nfacevertex = 2;
            nfaceperchild = 4;
            cfaceperpface = 2;
        end
    else #dim==3
        ### NOT READY
        printerr("Not ready to divide 3D grid for higher order FV. TODO")
        return (nothing, grid);
        if nvertex==4 # tet
            nchildren = 4; # divide into 4 hexes
            nfaces = 18;
            Ncnodes = Npnodes; # TODO
            Ncfaces = Npfaces*3 + Nparent*6; # each parent face becomes 3, plus 6 internal
            ncvertex = 8;
            nfacevertex = 4;
            nfaceperchild = 6;
            cfaceperpface = 3;
        elseif nvertex==8 # hex
            nchildren = 8;
            nfaces = 36;
            Ncnodes = Npnodes; # TODO
            Ncfaces = Npfaces*4 + Nparent*12; # each parent face becomes 4, plus 12 internal
            ncvertex = 8;
            nfacevertex = 4;
            nfaceperchild = 6;
            cfaceperpface = 4;
        end
    end
    Nchildren = nchildren * Nparent;
    
    # Pieces needed for the ParentGrid struct
    c2p = zeros(Int, 2, Nchildren);         # child to parent
    p2c = zeros(Int, nchildren, Nparent);   # parent to child
    p2f = zeros(Int, nfaces, Nparent);      # parent to face
    p2n = zeros(Int, nneighbor, Nparent);            # parent to neighbor
    
    # Pieces needed for the new child grid
    # Refer to grid.jl for details
    # allnodes = zeros(dim, Ncnodes); # First build DG grid, then remove duplicates
    bdry = Array{Array{Int,1},1}(undef,nbids);
    bdryface = Array{Array{Int,1},1}(undef,nbids);
    bdrynorm = Array{Array{Float64,2},1}(undef,nbids);
    bids = copy(grid.bids);
    loc2glb = zeros(Int, ncvertex, Nchildren);
    # glbvertex = zeros(Int, ncvertex, Nchildren); # will be identical to loc2glb
    face2glb = zeros(Int, nfacevertex, 1, Ncfaces);
    element2face = zeros(Int, nfaceperchild, Nchildren);
    face2element = zeros(Int, 2, Ncfaces);
    facenormals = zeros(dim, Ncfaces);
    faceRefelInd = zeros(Int, 2, Ncfaces);
    facebid = zeros(Int, Ncfaces);
    
    for i=1:nbids
        if dim==1
            bdry[i] = zeros(Int, length(grid.bdry[i])); # same number
        elseif dim==2
            bdry[i] = zeros(Int, length(grid.bdry[i]) + length(grid.bdryface[i])); # add one for each bdry face
        else
            bdry[i] = zeros(Int, length(grid.bdry[i])); # TODO
        end
        bdryface[i] = zeros(Int, length(grid.bdryface[i]) * cfaceperpface);
        bdrynorm[i] = zeros(dim, length(bdry[i]));
    end
    
    # All of the arrays are set up. Now fill them.
    # 1D is simple
    if dim==1
        # Just directly make the correct allnodes
        allnodes = zeros(1, Ncnodes);
        
        face_done = zeros(Int, Npfaces); # set to fid after adding it
        next_node = 1;
        next_child = 1;
        next_face = 1;
        next_bdryface = ones(Int, length(grid.bids));
        for ei=1:Nparent
            leftnode = grid.glbvertex[1,ei];
            rightnode = grid.glbvertex[2,ei];
            leftx = grid.allnodes[1,leftnode];
            rightx = grid.allnodes[1,rightnode];
            leftface = grid.element2face[1,ei];
            rightface = grid.element2face[2,ei];
            
            # child/parent maps
            for ci=1:nchildren
                p2c[ci,ei] = next_child;
                c2p[:,next_child] = [ei, ci];
                next_child += 1;
            end
            
            # neighbors
            if grid.face2element[1,leftface] == ei
                p2n[1,ei] = grid.face2element[2,leftface];
            else
                p2n[1,ei] = grid.face2element[1,leftface];
            end
            if grid.face2element[1,rightface] == ei
                p2n[2,ei] = grid.face2element[2,rightface];
            else
                p2n[2,ei] = grid.face2element[1,rightface];
            end
            
            # nodes and faces
            dx = (rightx-leftx)/nchildren;
            # The left face
            if face_done[leftface] == 0
                face_done[leftface] = next_face;
                p2f[1,ei] = next_face;
                
                allnodes[1, next_node] = leftx;
                loc2glb[1,p2c[1,ei]] = next_node;
                face2glb[1,1,next_face] = next_node;
                element2face[1, p2c[1,ei]] = next_face;
                face2element[1, next_face] = p2c[1,ei];
                facenormals[1,next_face] = leftx < rightx ? -1 : 1 #grid.facenormals[1,leftface];
                faceRefelInd[1, next_face] = 1; # left of element
                facebid[next_face] = grid.facebid[leftface];
                
                fbid = facebid[next_face];
                if fbid > 0
                    bdryface[fbid][next_bdryface[fbid]] = next_face;
                    # since a 1d bdry face is only one node
                    bdry[fbid][next_bdryface[fbid]] = next_node;
                    bdrynorm[fbid][next_bdryface[fbid]] = facenormals[1,next_face];
                    
                    next_bdryface[fbid] += 1;
                end
                
                next_node += 1;
                next_face += 1;
                
            else # parent face already set
                fid = face_done[leftface];
                p2f[1,ei] = fid;
                loc2glb[1,p2c[1,ei]] = face2glb[1,1,fid];
                element2face[1, p2c[1,ei]] = fid;
                face2element[2, fid] = p2c[1,ei];
                faceRefelInd[2, fid] = 1; # left of element
            end
            
            # The interior
            for ni=1:nchildren-1
                p2f[ni+1,ei] = next_face;
                
                allnodes[1, next_node] = leftx + ni*dx; 
                loc2glb[2,p2c[ni,ei]] = next_node;
                loc2glb[1,p2c[ni+1,ei]] = next_node;
                face2glb[1,1,next_face] = next_node;
                element2face[2, p2c[ni,ei]] = next_face;
                element2face[1, p2c[ni+1,ei]] = next_face;
                face2element[1, next_face] = p2c[ni,ei];
                face2element[2, next_face] = p2c[ni+1,ei];
                facenormals[1,next_face] = leftx < rightx ? 1 : -1  # will point right because building from left
                faceRefelInd[1, next_face] = 2; # right of element
                faceRefelInd[2, next_face] = 1; # left of element
                facebid[next_face] = 0;
                
                next_node += 1;
                next_face += 1;
            end
            
            # The right face
            if face_done[rightface] == 0
                face_done[rightface] = next_face;
                p2f[nchildren+1,ei] = next_face;
                
                allnodes[1, next_node] = rightx;
                loc2glb[2,p2c[nchildren,ei]] = next_node;
                face2glb[1,1,next_face] = next_node;
                element2face[2, p2c[nchildren,ei]] = next_face;
                face2element[1, next_face] = p2c[nchildren,ei];
                facenormals[1,next_face] = leftx < rightx ? 1 : -1 
                faceRefelInd[1, next_face] = 2; # right of element
                facebid[next_face] = grid.facebid[rightface];
                
                fbid = facebid[next_face];
                if fbid > 0
                    bdryface[fbid][next_bdryface[fbid]] = next_face;
                    # since a 1d bdry face is only one node
                    bdry[fbid][next_bdryface[fbid]] = next_node;
                    bdrynorm[fbid][next_bdryface[fbid]] = facenormals[1,next_face];
                    
                    next_bdryface[fbid] += 1;
                end
                
                next_node += 1;
                next_face += 1;
                
            else # parent face already set
                fid = face_done[rightface];
                p2f[nchildren,ei] = fid;
                loc2glb[2,p2c[nchildren,ei]] = face2glb[1,1,fid];
                element2face[2, p2c[nchildren,ei]] = fid;
                face2element[2, fid] = p2c[nchildren,ei];
                faceRefelInd[2, fid] = 2; # right of element
            end
            
        end # parent loop
        
    elseif dim==2
        # Make the DG nodes, then remove duplicates
        if length(grid.element2face[:,1]) == 3 # triangle
            tmpallnodes = zeros(2, Nparent * 6);
        else
            tmpallnodes = zeros(2, Nparent * 9);
        end
        
        face_done = zeros(Int, 2, Npfaces); # set to fid after adding it (each parent face -> 2 child faces)
        vertex_done = zeros(Int, Npnodes); # set to node index after adding it
        next_node = 1;
        next_child = 1;
        next_face = 1;
        next_bdryface = ones(Int, length(grid.bids));
        for ei=1:Nparent
            pnodes = grid.glbvertex[:,ei];
            pnodex = grid.allnodes[:, pnodes];
            pfaces = grid.element2face[:,ei];
            
            # child/parent maps
            #          1
            #         / \
            #    n1  /c1 \  n3
            #       /_____\
            #      / \c4 / \
            #     /c2 \ /c3 \ 
            #    2_____V_____3 
            #         n2
            #       
            #        n3
            #    4---------3
            #    | c4 | c3 |
            # n4 |---------| n2
            #    | c1 | c2 | 
            #    1---------2
            #        n1
            for ci=1:nchildren
                p2c[ci,ei] = next_child;
                c2p[:,next_child] = [ei, ci];
                next_child += 1;
            end
            
            # neighbors    1
            local_face_ind = zeros(Int, length(pfaces));
            for fi=1:length(pfaces)
                # figure out the local index of the corresponding face in grid
                lfi = 0;
                for fj=1:length(pfaces)
                    if pnodes[fj] in grid.face2glb[:,1,pfaces[fi]]
                        if fj < length(pfaces) && pnodes[fj+1] in grid.face2glb[:,1,pfaces[fi]]
                            lfi = fj;
                        elseif fj == length(pfaces) && pnodes[1] in grid.face2glb[:,1,pfaces[fi]]
                            lfi = fj;
                        else
                            lfi = fj>1 ? fj-1 : length(pfaces);
                        end
                    end
                end
                if lfi == 0
                    println("error: local face index was 0");
                    lfi = fi;
                end
                local_face_ind[fi] = lfi;
                
                if grid.face2element[1,pfaces[fi]] == ei
                    p2n[lfi,ei] = grid.face2element[2,pfaces[fi]];
                else
                    p2n[lfi,ei] = grid.face2element[1,pfaces[fi]];
                end
            end
            # reorder pfaces to match local
            tmp = zeros(Int, length(pfaces))
            for fi=1:length(pfaces)
                tmp[local_face_ind[fi]] = pfaces[fi];
            end
            pfaces = tmp;
            
            # println("lfi: "*string(local_face_ind));
            # println("pfaces: "*string(pfaces));
            # println("pnodes: "*string(pnodes));
            
            # nodes and faces
            # Here things have to be done separately for triangles and quads
            if length(pfaces) == 3 # triangle
                child_nodes = zeros(2,6);
                child2loc = zeros(Int, 3, 4);
                child2face = zeros(Int, 3, 4);
                
                child_nodes[:,1:3] = pnodex[:,1:3];
                child_nodes[:,4] = (pnodex[:,1] + pnodex[:,2])/2;
                child_nodes[:,5] = (pnodex[:,2] + pnodex[:,3])/2;
                child_nodes[:,6] = (pnodex[:,1] + pnodex[:,3])/2;
                tmpallnodes[:,((ei-1)*6 + 1):(ei*6)] = child_nodes;
                
                child2loc[:,1] = [1, 4, 6];
                child2loc[:,2] = [2, 5, 4];
                child2loc[:,3] = [3, 6, 5];
                child2loc[:,4] = [4, 5, 6];
                child2face[:,1] = [1, 7, 6];
                child2face[:,2] = [3, 8, 2];
                child2face[:,3] = [5, 9, 4];
                child2face[:,4] = [8, 9, 7];
                face2loc = [1 4; 4 2; 2 5; 5 3; 3 6; 6 1; 4 6; 4 5; 5 6]; # local index of face nodes
                face2child = [1 0; 2 0; 2 0; 3 0; 3 0; 1 0; 1 4; 2 4; 3 4]; # elements having this face (local index)
                
                parent2glb = ((ei-1)*6+1):(ei*6); # global index of parent nodes
                parentface2glb = zeros(2,9); # global index of all face nodes in parent
                for fi=1:9
                    parentface2glb[:,fi] = parent2glb[face2loc[fi,:]];
                end
                
                # The external faces
                for fi=1:3
                    if face_done[1,pfaces[fi]] == 0
                        face_done[1,pfaces[fi]] = next_face;
                        face_done[2,pfaces[fi]] = next_face+1;
                        
                        p2f[fi*2-1,ei] = next_face;
                        p2f[fi*2,ei] = next_face+1;
                        
                        face2element[1, next_face] = p2c[face2child[2*fi-1,1],ei];
                        face2element[1, next_face+1] = p2c[face2child[2*fi,1],ei];
                        # element2face[1, p2c[1,ei]] = next_face; # do later
                        facenormals[:,next_face] = grid.facenormals[:,pfaces[fi]];
                        facenormals[:,next_face+1] = grid.facenormals[:,pfaces[fi]];
                        faceRefelInd[1, next_face] = 1;
                        faceRefelInd[1, next_face+1] = 3;
                        facebid[next_face] = grid.facebid[pfaces[fi]];
                        facebid[next_face+1] = grid.facebid[pfaces[fi]];
                        
                        fbid = facebid[next_face];
                        if fbid > 0
                            bdryface[fbid][next_bdryface[fbid]] = next_face;
                            bdryface[fbid][next_bdryface[fbid]+1] = next_face+1;
                            
                            next_bdryface[fbid] += 2;
                        end
                        
                        next_face += 2;
                        
                    else # parent face already set
                        same_orientation = faceRefelInd[face_done[1,pfaces[fi]]] == 1;
                        if same_orientation
                            fid1 = face_done[1,pfaces[fi]];
                            fid2 = face_done[2,pfaces[fi]];
                        else
                            fid1 = face_done[2,pfaces[fi]];
                            fid2 = face_done[1,pfaces[fi]];
                        end
                        
                        p2f[fi*2-1,ei] = fid1;
                        p2f[fi*2,ei] = fid2;
                        
                        face2element[2, fid1] = p2c[face2child[2*fi-1,1],ei];
                        face2element[2, fid2] = p2c[face2child[2*fi,1],ei];
                        faceRefelInd[2, fid1] = 1;
                        faceRefelInd[2, fid2] = 3;
                    end
                end # exterior faces
                
                # Interior faces
                p2f[7:9,ei] = next_face:(next_face+2);
                face2element[1, next_face:(next_face+2)] = p2c[face2child[7:9,1],ei];
                face2element[2, next_face:(next_face+2)] = p2c[face2child[7:9,2],ei];
                facenormals[:,next_face] = grid.facenormals[:,pfaces[2]];
                facenormals[:,next_face+1] = grid.facenormals[:,pfaces[3]];
                facenormals[:,next_face+2] = grid.facenormals[:,pfaces[1]];
                faceRefelInd[:, next_face] = [2,3];
                faceRefelInd[:, next_face+1] = [2,1];
                faceRefelInd[:, next_face+2] = [2,2];
                facebid[next_face:(next_face+2)] = [0,0,0];
                
                next_face += 3;
                
                # Still need to do: loc2glb, face2glb, element2face, bdry, bdrynorm
                for ci=1:4
                    loc2glb[:, p2c[ci,ei]] = parent2glb[child2loc[:,ci]];
                    element2face[:, p2c[ci,ei]] = p2f[child2face[:,ci],ei];
                end
                for fi=1:9
                    face2glb[:, 1, p2f[fi,ei]] = parent2glb[face2loc[fi,:]];
                end
                
                # println("p2glb for "*string(ei)*": "*string(parent2glb))
                    
            else # quad
                # TODO
            end
            
        end # parent loop
        
        # println(face2glb[:,1,:])
        
        # Since a DG grid was made, remove duplicate nodes and update loc2glb and face2glb
        (allnodes, loc2glb, face2glb) = remove_duplicate_nodes(tmpallnodes, loc2glb, other2glb=face2glb);
        
    elseif dim==3
        #TODO
    end
    
    
    child_grid = Grid(allnodes, bdry, bdryface, bdrynorm, bids, loc2glb, loc2glb, face2glb, element2face, face2element, facenormals, faceRefelInd, facebid);
    tmp_parent_maps = ParentMaps(c2p, p2c, p2f, p2n, zeros(Int,0,0)); # no patches built yet
    # build patches
    ncells_in_patch = (nneighbor+1)*nchildren;
    patches = zeros(Int, ncells_in_patch, Nparent);
    for ei=1:Nparent
        patches[:, ei] = build_local_patch(tmp_parent_maps, child_grid, ei);
    end
    parent_maps = ParentMaps(c2p, p2c, p2f, p2n, patches);
    
    return (parent_maps, child_grid);
end

# Builds the local patch given a central parent.
function build_local_patch(maps, grid, center)
    dim = size(grid.allnodes,1);
    if dim == 1
        # | neighbor 1 | center | neighbor 2| -> | n+1..2n | 1..n | 2n+1..3n |
        nchildren = size(maps.parent2child,1); # (assumes one element type)
        patch = zeros(Int, nchildren*3); # (assumes one element type)
        patch[1:nchildren] = maps.parent2child[:,center];
        for neighborid=1:2
            if maps.parent2neighbor[neighborid, center] == 0
                # This is a boundary face with no neighbor. Set these cells to zero.
                patch[(neighborid*nchildren+1):((neighborid+1)*nchildren)] = zeros(Int, nchildren);
            else
                # Check for orientation
                if maps.parent2face[1, center] == maps.parent2face[end, maps.parent2neighbor[neighborid,center]] || maps.parent2face[end, center] == maps.parent2face[1, maps.parent2neighbor[neighborid,center]]
                    patch[(neighborid*nchildren+1):((neighborid+1)*nchildren)] = maps.parent2child[:,maps.parent2neighbor[neighborid,center]];
                else # reversed orientation
                    patch[((neighborid+1)*nchildren):-1:(neighborid*nchildren+1)] = maps.parent2child[:,maps.parent2neighbor[neighborid,center]];
                end
            end
        end
        
    elseif dim == 2
        # Triangles and quads will be done separately
        if size(maps.parent2neighbor,1) == 3 # triangle
            #          1
            #         / \
            #    n1  /c1 \  n3
            #       /_____\
            #      / \c4 / \
            #     /c2 \ /c3 \ 
            #    2_____V_____3 
            #         n2
            # Neighbor orientation could have six configurations.
            # Determine this by face ID.
            orientation_table = [
                [1, 3, 2, 4],
                [2, 3, 1, 4],
                [2, 1, 3, 4],
                [3, 1, 2, 4],
                [3, 2, 1, 4],
                [1, 2, 3, 4]
            ]
            
            patch = zeros(Int, 4 * 4);
            patch[1:4] = maps.parent2child[:,center];
            
            neighbors = maps.parent2neighbor[:,center];
            cfaces = maps.parent2face[[1,3,5],center]; # first face on each side of parent
            orientation = [0,0,0]; # orientation index for each neighbor
            for ni=1:3
                if neighbors[ni] > 0 # not a boundary
                    for fi=1:6
                        if maps.parent2face[fi,neighbors[ni]] == cfaces[ni]
                            orientation[ni] = fi; # This is the index of the face touching cfaces[ni]
                            break;
                        end
                    end
                    # Use the orientation table to populate the patch
                    patch[(ni*4+1):((ni+1)*4)] = maps.parent2child[orientation_table[orientation[ni]], neighbors[ni]];
                end
            end
            
        else # quad
            # TODO
        end
        
    elseif dim == 3
        # TODO
    end
    
    return patch;
end