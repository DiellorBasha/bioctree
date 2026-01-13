function [eigenvalues, eigenvectors] = eigenmodes(varargin)
%EIGENMODES Compute eigenmodes of Laplace-Beltrami operator
%
% Syntax (Manifold-based):
%   [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(M, k)
%   [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(M, k, 'RemoveDC', true)
%   [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(M, k, 'MassType', 'voronoi')
%
% Syntax (Matrix-based):
%   [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(K, Mass, k)
%   [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(K, Mass, k, 'RemoveDC', true)
%
% Inputs (Manifold-based):
%   M        - bct.Manifold object
%   k        - Number of eigenmodes to compute
%
% Inputs (Matrix-based):
%   K        - [N×N] stiffness/cotangent matrix (sparse)
%   Mass     - [N×N] mass matrix (sparse)
%   k        - Number of eigenmodes to compute
%
% Optional Parameters:
%   RemoveDC  - Remove DC (constant) mode (default: true)
%   MassType  - Mass matrix type: 'voronoi' (default), 'barycentric', 'full'
%               (only used with Manifold-based syntax)
%   EigsOpts  - Additional options passed to eigs (struct)
%
% Outputs:
%   eigenvalues  - [k×1] eigenvalues (sorted ascending, smallest first)
%   eigenvectors - [N×k] eigenvectors (M-orthonormal columns)
%
% Description:
%   Solves the generalized eigenvalue problem:
%     K * u = λ * M * u
%   
%   Where:
%   - K is the stiffness (cotangent) matrix
%   - M is the mass matrix
%   - λ are eigenvalues of the Laplace-Beltrami operator
%   - u are eigenmodes (eigenvectors)
%
%   The eigenvectors are M-orthonormal: U' * M * U = I
%   Eigenvalues are returned in ascending order: λ₀ ≤ λ₁ ≤ ... ≤ λₖ
%
%   By default, the DC (constant) mode (smallest eigenvalue, typically ~0)
%   is removed. Set 'RemoveDC' to false to keep all modes.
%
%   Two input modes:
%   1. Manifold-based: Extracts K and M from bct.Manifold object
%   2. Matrix-based: Accepts K and M directly for standalone computation
%
%   Implementation uses bct.manifold.eigen package:
%   - Uses smallest-magnitude eigenvalues ('SM')
%   - Enforces M-orthonormality via whitening
%   - Same normalization and DC removal strategy
%
% Examples:
%   % Manifold-based usage
%   [lambda, U] = bct.manifold.eigenmodes(M, 100);
%
%   % Matrix-based usage (standalone)
%   K = bct.manifold.cotmatrix(M);
%   Mass = bct.manifold.massmatrix(M);
%   [lambda, U] = bct.manifold.eigenmodes(K, Mass, 100);
%
%   % Keep DC mode
%   [lambda, U] = bct.manifold.eigenmodes(M, 100, 'RemoveDC', false);
%
%   % Use barycentric mass matrix (Manifold-based only)
%   [lambda, U] = bct.manifold.eigenmodes(M, 100, 'MassType', 'barycentric');
%
%   % Project signal onto eigenmodes
%   [lambda, U] = bct.manifold.eigenmodes(M, 100);
%   Mass = M.massmatrix();
%   coeffs = U' * Mass * signal;  % Spectral coefficients
%   reconstructed = U * coeffs;    % Reconstruct signal
%
%   % Spectral filtering (heat kernel)
%   tau = 10;
%   heat_kernel = exp(-lambda * tau);
%   filtered = U * (heat_kernel .* coeffs);
%
% See also: bct.manifold.massmatrix, bct.manifold.cotmatrix,
%           bct.manifold.eigen.solve, bct.manifold.eigen

% Parse input arguments to determine mode
if nargin >= 1 && isa(varargin{1}, 'bct.Manifold')
    % Manifold-based mode
    p = inputParser;
    p.addRequired('Manifold', @(x) isa(x, 'bct.Manifold'));
    p.addRequired('numModes', @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('RemoveDC', true, @islogical);
    p.addParameter('MassType', "voronoi", @(x) isstring(x) || ischar(x));
    p.addParameter('EigsOpts', struct(), @isstruct);
    p.parse(varargin{:});
    
    Manifold = p.Results.Manifold;
    numModes = p.Results.numModes;
    removeDC = p.Results.RemoveDC;
    massType = string(p.Results.MassType);
    eigsOpts = p.Results.EigsOpts;
    
    % Get FEM matrices from manifold (uses caching)
    K = Manifold.cotmatrix();
    M = Manifold.massmatrix('Type', massType);
    
elseif nargin >= 3 && (issparse(varargin{1}) || ismatrix(varargin{1})) && ...
                      (issparse(varargin{2}) || ismatrix(varargin{2}))
    % Matrix-based mode
    p = inputParser;
    p.addRequired('K', @(x) (issparse(x) || ismatrix(x)) && ismatrix(x));
    p.addRequired('M', @(x) (issparse(x) || ismatrix(x)) && ismatrix(x));
    p.addRequired('numModes', @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('RemoveDC', true, @islogical);
    p.addParameter('EigsOpts', struct(), @isstruct);
    p.parse(varargin{:});
    
    K = p.Results.K;
    M = p.Results.M;
    numModes = p.Results.numModes;
    removeDC = p.Results.RemoveDC;
    eigsOpts = p.Results.EigsOpts;
    
    % Validate matrix dimensions
    assert(size(K, 1) == size(K, 2), 'Stiffness matrix K must be square');
    assert(size(M, 1) == size(M, 2), 'Mass matrix M must be square');
    assert(size(K, 1) == size(M, 1), 'K and M must have same dimensions');
    
else
    error('bct:manifold:eigenmodes:InvalidInput', ...
        ['Invalid input arguments.\n' ...
         'Usage:\n' ...
         '  [lambda, U] = bct.manifold.eigenmodes(Manifold, k, ...)\n' ...
         '  [lambda, U] = bct.manifold.eigenmodes(K, Mass, k, ...)']);
end

% Solve generalized eigenproblem using bct.manifold.eigen package
[eigenvectors, eigenvalues] = bct.manifold.eigen.solve(K, M, numModes, ...
    'EigsOpts', eigsOpts);

% Remove DC mode if requested (default: true)
if removeDC
    [eigenvectors, eigenvalues] = bct.manifold.eigen.removeDC(eigenvectors, eigenvalues);
end

% Normalize eigenvectors (enforce M-orthonormality)
eigenvectors = bct.manifold.eigen.normalize(eigenvectors, M);

% Report
fprintf('bct.manifold.eigenmodes: Eigendecomposition complete\n');
fprintf('  Requested modes: %d\n', numModes);
fprintf('  Retained modes:  %d\n', size(eigenvectors, 2));
fprintf('  Eigenvalue range: [%.6f, %.6f]\n', min(eigenvalues), max(eigenvalues));

end
