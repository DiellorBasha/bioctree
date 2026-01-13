function w = femWeights(Manifold)
%FEMWEIGHTS Compute FEM-based edge weights (cotangent)
%
% Syntax:
%   w = bct.manifold.query.femWeights(Manifold)
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
% See also: bct.manifold.query.edgeLengths, bct.manifold.operator.stiffness

arguments
    Manifold (1,1) bct.Manifold
end

% Extract vertices and faces
V = Manifold.Vertices;
F = Manifold.Faces;

% Compute gradient/divergence matrix from gptoolbox
G = grad(V, F);
K = G' * G;  % Stiffness matrix = G^T * G

E = Manifold.Edges;
i = E(:,1);
j = E(:,2);

% Extract cotangent weights
w = -K(sub2ind(size(K), i, j));
w(w < 0) = 0;  % numerical safety

end
