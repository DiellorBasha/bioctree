function K = assembleStiffness(Manifold)
%ASSEMBLESTIFFNESS Assemble FEM stiffness (cotangent) matrix from Manifold
%
% Syntax:
%   K = bct.fem.assembleStiffness(Manifold)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Outputs:
%   K - [N×N] sparse stiffness matrix (cotangent Laplacian)
%
% Notes:
%   - Uses gptoolbox cotmatrix() as authoritative source
%   - Represents discrete Dirichlet energy: ⟨∇u, ∇v⟩
%   - Positive semi-definite on closed manifolds
%   - K defines the Laplace-Beltrami operator: L = M^(-1) * K
%
% See also: cotmatrix, bct.fem.assembleMass

arguments
    Manifold (1,1) bct.Manifold
end

% Use gptoolbox as authoritative source for FEM computations
K = cotmatrix(Manifold.Vertices, Manifold.Faces);

end
