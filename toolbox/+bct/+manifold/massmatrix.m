function M = massmatrix(Manifold, options)
%MASSMATRIX Assemble FEM mass matrix from Manifold [DELEGATES TO bct.manifold.operator.mass]
%
% Syntax:
%   M = bct.manifold.massmatrix(Manifold)
%   M = bct.manifold.massmatrix(Manifold, 'Type', massType)
%
% This function delegates to bct.manifold.operator.mass for compatibility.
% New code should use bct.manifold.operator.mass directly.
%
% See also: bct.manifold.operator.mass, bct.manifold.cotmatrix

arguments
    Manifold (1,1) bct.Manifold
    options.Type (1,1) string {mustBeMember(options.Type, ["voronoi","barycentric","full"])} = "voronoi"
end

% Delegate to bct.manifold.operator.mass
M = bct.manifold.operator.mass(Manifold, 'Type', options.Type);

end
