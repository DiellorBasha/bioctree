function [TR, V, F, Nx, Ny, vert2grid_lin, grid2vert, xvals, yvals] = surfaceMeshFromGridGraph(G)
% surfaceMeshFromGridGraph  Build a triangular surface mesh from a 2D grid graph (GSPBox).
%
% SYNTAX:
%   [TR, V, F, Nx, Ny, vert2grid_lin, grid2vert, xvals, yvals] = surfaceMeshFromGridGraph(G)
%
% INPUT:
%   G  - GSPBox graph returned by gsp_2dgrid(Nx,Ny) or gsp_2dgrid(N)
%
% OUTPUTS:
%   TR            - triangulation object (faces F over vertices V=[x y z])
%   V             - (#V x 3) vertices [x y z], z initialized to zeros
%   F             - (#F x 3) faces (1-based indices into V)
%   Nx, Ny        - grid dimensions along x and y
%   vert2grid_lin - (#V x 1) linear grid index (sub2ind([Ny,Nx], j, i)) for each vertex id
%   grid2vert     - (Ny*Nx x 1) map from linear grid index -> vertex id
%   xvals, yvals  - sorted unique x and y coordinates (length Nx, Ny)
%
% NOTE:
%   - We infer (i,j) grid indices by sorting G.coords(:,1) and (:,2).
%   - Two triangles per rectangular cell: (i,j)-(i+1,j)-(i+1,j+1) and (i,j)-(i+1,j+1)-(i,j+1)

    if ~isfield(G, 'coords')
        error('G must have a .coords field (use gsp_2dgrid).');
    end
    Vxy = G.coords;               % (#V x 2)
    V   = [Vxy, zeros(size(Vxy,1),1)];  % z=0 surface (flat)

    x = Vxy(:,1);   y = Vxy(:,2);
    xvals = unique(x, 'sorted');
    yvals = unique(y, 'sorted');
    Nx = numel(xvals);
    Ny = numel(yvals);

    % Map each vertex to its grid (i,j) by locating its x,y in the sorted unique lists
    [~, ix] = ismember(x, xvals);   % 1..Nx
    [~, iy] = ismember(y, yvals);   % 1..Ny

    % Linear index of each vertex in Ny-by-Nx array (row = y-index, col = x-index)
    vert2grid_lin = sub2ind([Ny, Nx], iy, ix);

    % Inverse map: for each grid cell (linear), which vertex id?
    grid2vert = zeros(Nx*Ny, 1);
    grid2vert(vert2grid_lin) = (1:numel(vert2grid_lin)).';

    % Build two triangles per quad
    F = zeros(2*(Nx-1)*(Ny-1), 3);
    t = 1;
    for j = 1:(Ny-1)
        for i = 1:(Nx-1)
            lin11 = sub2ind([Ny,Nx], j,   i  );
            lin21 = sub2ind([Ny,Nx], j,   i+1);
            lin12 = sub2ind([Ny,Nx], j+1, i  );
            lin22 = sub2ind([Ny,Nx], j+1, i+1);

            v11 = grid2vert(lin11);
            v21 = grid2vert(lin21);
            v12 = grid2vert(lin12);
            v22 = grid2vert(lin22);

            % diag: (v11, v21, v22) and (v11, v22, v12)
            F(t,:)   = [v11, v21, v22]; t = t + 1;
            F(t,:)   = [v11, v22, v12]; t = t + 1;
        end
    end

    TR = triangulation(F, V);
end
