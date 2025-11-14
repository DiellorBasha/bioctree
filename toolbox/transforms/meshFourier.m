function [U, lam, K, M, D, Ls] = meshFourier(mesh, varargin)
% meshFourier - Compute Fourier (spectral) basis of a triangular mesh
%
% Computes the eigendecomposition of the normalized graph Laplacian
% to obtain a spectral basis for signals defined on mesh vertices.
% This basis is analogous to the Fourier transform for manifolds.
%
% Syntax:
%   [U, lam] = meshFourier(mesh)
%   [U, lam] = meshFourier(mesh, k)
%   [U, lam] = meshFourier(mesh, k, opts)
%   [U, lam, K, M] = meshFourier(...)
%   [U, lam, K, M, D, Ls] = meshFourier(...)
%   [U, lam, ...] = meshFourier(V, F, ...)  % Alternative syntax
%
% Inputs:
%   mesh - MATLAB surfaceMesh object with Vertices and Faces properties
%          OR
%   V    - [N×3] vertex positions matrix
%   F    - [M×3] face connectivity matrix (triangle indices)
%   
%   k    - (optional) Number of eigenvalues/eigenvectors to compute
%          Default: min(600, NumVertices-1)
%   opts - (optional) Structure with fields:
%          .tol     - Convergence tolerance (default: 1e-10)
%          .maxit   - Maximum iterations (default: 5000)
%          .sigma   - Eigenvalue shift for conditioning (default: 1e-6)
%
% Outputs:
%   U   - [N×K] matrix of eigenvectors (Fourier basis functions)
%         Each column is a spatial frequency mode on the mesh
%   lam - [K×1] vector of eigenvalues (spatial frequencies)
%         Sorted in ascending order, DC component removed
%   K   - [N×N] sparse cotangent Laplacian (stiffness) matrix
%   M   - [N×N] sparse diagonal mass matrix (vertex areas)
%   D   - [K×K] diagonal matrix of eigenvalues (as returned by eigs)
%   Ls  - [N×N] sparse normalized Laplacian matrix
%
% Notes:
%   - Requires gptoolbox functions: cotmatrix, massmatrix
%     Expected location: external/gptoolbox
%   - Uses normalized Laplacian for numerical stability
%   - Removes DC component (constant mode) and negative eigenvalues
%   - Vertex positions should be in consistent units (mm recommended)
%
% Examples:
%   % Using surfaceMesh object
%   mesh = surfaceMesh(V, F);
%   [U, lam] = meshFourier(mesh, 500);
%   
%   % Using vertices and faces directly
%   [U, lam] = meshFourier(V, F, 500);
%   
%   % Get all outputs including normalized Laplacian
%   [U, lam, K, M, D, Ls] = meshFourier(mesh);
%   
%   % Project signal onto first 100 modes:
%   signal = rand(size(V,1), 1);
%   coeffs = U(:,1:100)' * (M * signal);
%   reconstruction = U(:,1:100) * coeffs;
%
% See also: eigs, cotmatrix, massmatrix

% Check for gptoolbox availability
if ~exist('cotmatrix', 'file') || ~exist('massmatrix', 'file')
    % Try to add gptoolbox to path
    bioctree_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    gptoolbox_path = fullfile(bioctree_root, 'external', 'gptoolbox', 'mesh');
    
    if exist(gptoolbox_path, 'dir')
        addpath(gptoolbox_path);
        if ~exist('cotmatrix', 'file') || ~exist('massmatrix', 'file')
            error('meshFourier:MissingDependency', ...
                'gptoolbox functions (cotmatrix, massmatrix) not found in: %s', gptoolbox_path);
        end
    else
        error('meshFourier:MissingDependency', ...
            ['gptoolbox is required but not found.\n' ...
             'Expected location: %s\n' ...
             'Please ensure gptoolbox is installed in external/gptoolbox'], ...
            fullfile(bioctree_root, 'external', 'gptoolbox'));
    end
end

% Parse inputs - handle both (mesh, k, opts) and (V, F, k, opts) syntaxes
if nargin < 1
    error('meshFourier:InvalidInput', 'At least one input argument is required');
end

% Determine if first input is surfaceMesh object or vertices array
if isa(mesh, 'surfaceMesh')
    % Extract mesh geometry from surfaceMesh object
    V = mesh.Vertices;
    F = mesh.Faces;
    N = mesh.NumVertices;
    arg_offset = 0;  % varargin starts with k
elseif isnumeric(mesh) && nargin >= 2 && isnumeric(varargin{1})
    % First two inputs are V, F matrices
    V = mesh;
    F = varargin{1};
    N = size(V, 1);
    arg_offset = 1;  % varargin{2} is k
    
    % Validate V and F
    if size(V, 2) ~= 3
        error('meshFourier:InvalidInput', 'Vertex matrix V must be N×3');
    end
    if size(F, 2) ~= 3
        error('meshFourier:InvalidInput', 'Face matrix F must be M×3');
    end
else
    error('meshFourier:InvalidInput', ...
        'First input must be a surfaceMesh object or vertex matrix V (with F as second input)');
end

% Parse k and opts from remaining arguments
if length(varargin) > arg_offset
    k = varargin{arg_offset + 1};
else
    k = [];
end

if length(varargin) > arg_offset + 1
    opts = varargin{arg_offset + 2};
else
    opts = [];
end

% Default number of modes
if isempty(k)
    k = min(600, N - 1);
end

% Validate k
if k < 1 || k >= N
    error('meshFourier:InvalidK', 'k must be between 1 and NumVertices-1 (got k=%d, N=%d)', k, N);
end

% Default options
if isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'tol'),   opts.tol = 1e-10; end
if ~isfield(opts, 'maxit'), opts.maxit = 5000; end
if ~isfield(opts, 'sigma'), opts.sigma = 1e-6; end
if ~isfield(opts, 'isreal'), opts.isreal = true; end

% --- Core computation (unchanged logic) ---

% Operators (gptoolbox)
K = -cotmatrix(V, F);                                   % PSD stiffness
M = massmatrix(V, F, 'barycentric');                    % diagonal, >0
K = (K+K.')/2;                                          % enforce symmetry
d = full(diag(M)); 
M = spdiags(d,0,length(d),length(d));

% Normalized Laplacian (more numerically tame since M is diagonal)
Sinv = spdiags(1./sqrt(d), 0, length(d), length(d));
Ls = (Sinv*K*Sinv); 
Ls = (Ls + Ls.')/2;

% --- Eigen solve near zero: use a tiny positive shift to aid convergence ---
[U, D] = eigs(Ls, k, opts.sigma, opts);        % shift-invert around ~0+
lam = real(diag(D));

% Clean numerical fuzz
tol = 1e-10 * max(1, max(abs(lam)));      % tolerant but safe
lam(lam < 0 & lam > -tol) = 0;

% Drop DC and any negatives beyond tolerance
mask = lam > tol;
lam  = lam(mask);
U    = U(:,mask);
D    = D(mask, mask);  % Filter D to match filtered eigenvalues

end