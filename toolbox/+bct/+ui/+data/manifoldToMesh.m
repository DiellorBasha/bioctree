function [V, F] = manifoldToMesh(M)
%MANIFOLDTOMESH Extract mesh geometry from Manifold object
%
% Syntax:
%   [V, F] = bct.ui.data.manifoldToMesh(M)
%
% Inputs:
%   M - bct.Manifold object
%
% Outputs:
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity
%
% Purpose:
%   Data adapter that extracts raw mesh geometry from Manifold
%   for use by Inspector components that only need Vertices/Faces.
%
% See also: bct.Manifold, bct.ui.manifold.Inspector

arguments
    M (1,1) bct.Manifold
end

V = M.Vertices;
F = M.Faces;

end
