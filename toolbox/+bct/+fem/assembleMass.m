function M = assembleMass(Manifold, massType)
%ASSEMBLEMASS Assemble FEM mass matrix from Manifold
%
% Syntax:
%   M = bct.fem.assembleMass(Manifold)
%   M = bct.fem.assembleMass(Manifold, massType)
%
% Inputs:
%   Manifold - bct.Manifold object
%   massType - 'voronoi' (default), 'barycentric', or 'full'
%
% Outputs:
%   M - [N×N] sparse mass matrix defining FEM inner product
%
% Notes:
%   - Uses gptoolbox massmatrix() as authoritative source
%   - 'voronoi' gives lumped (diagonal) mass (default)
%   - 'barycentric' gives barycentric dual cell areas
%   - 'full' gives consistent (dense) mass matrix
%
% See also: massmatrix, bct.fem.assembleStiffness

arguments
    Manifold (1,1) bct.Manifold
    massType (1,1) string {mustBeMember(massType, ["voronoi","barycentric","full"])} = "voronoi"
end

% Use gptoolbox as authoritative source for FEM computations
M = massmatrix(Manifold.Vertices, Manifold.Faces, char(massType));

end
