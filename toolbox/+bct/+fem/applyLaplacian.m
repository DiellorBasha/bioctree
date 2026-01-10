function y = applyLaplacian(Stiffness, Mass, x)
%APPLYLAPLACIAN Apply Laplace-Beltrami operator to signal
%
% Syntax:
%   y = bct.fem.applyLaplacian(Stiffness, Mass, x)
%
% Inputs:
%   Stiffness - [N×N] sparse stiffness matrix K
%   Mass      - [N×N] sparse mass matrix M
%   x         - [N×1] signal vector
%
% Outputs:
%   y - [N×1] result of L*x where L = M^(-1)*K
%
% Notes:
%   - Numerical application of discrete Laplace-Beltrami
%   - Uses backslash (direct solve) for M^(-1)
%   - Not a spectral computation (use eigenpairs for that)
%   - Suitable for iterative methods, preconditioning
%
% See also: bct.FEM.applyLaplacian

arguments
    Stiffness (:,:) {mustBeSparse}
    Mass      (:,:) {mustBeSparse}
    x         (:,1) double
end

% Validate dimensions
N = size(Mass, 1);
assert(size(Stiffness, 1) == N && size(Stiffness, 2) == N, ...
    'bct:fem:DimensionMismatch', 'Stiffness and Mass must match dimensions');
assert(length(x) == N, ...
    'bct:fem:SignalMismatch', 'Signal length must match matrix size');

% Apply L = M^(-1) * K
y = Mass \ (Stiffness * x);

end
