function w = femWeights(Manifold)
%FEMWEIGHTS Compute FEM-based edge weights (cotangent)
%
% Syntax:
%   w = bct.graph.femWeights(Manifold)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Returns:
%   w - [E×1] vector of FEM weights (physics-aligned)
%
% Notes:
%   - Uses cotangent stiffness matrix values
%   - Physics-aligned metric for diffusion/heat processes
%   - Negative values are clamped to zero for numerical safety
%
% See also: bct.graph.edgeLengths, bct.manifold.cotmatrix

arguments
    Manifold (1,1) bct.Manifold
end

% Get stiffness matrix from FEM
fem = Manifold.FEM();
K = fem.Stiffness;

E = Manifold.Edges;
i = E(:,1);
j = E(:,2);

% Extract cotangent weights
w = -K(sub2ind(size(K), i, j));
w(w < 0) = 0;  % numerical safety

end
