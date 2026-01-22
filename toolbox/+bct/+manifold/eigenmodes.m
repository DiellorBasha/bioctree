function eigen = eigenmodes(varargin)
%EIGENMODES Compute eigenmodes of Laplace-Beltrami operator (schema-compliant)
%
% Syntax (Manifold-based):
%   eigen = bct.manifold.eigenmodes(M, k)
%   eigen = bct.manifold.eigenmodes(M, k, 'RemoveDC', true)
%   eigen = bct.manifold.eigenmodes(M, k, 'MassType', 'voronoi')
%
% Syntax (Matrix-based):
%   eigen = bct.manifold.eigenmodes(K, Mass, k)
%   eigen = bct.manifold.eigenmodes(K, Mass, k, 'RemoveDC', true)
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
%   RemoveDC  - Remove DC (constant) mode (default: false)
%   MassType  - Mass matrix type: 'voronoi' (default), 'barycentric', 'full'
%               (only used with Manifold-based syntax)
%   EigsOpts  - Additional options passed to eigs (struct)
%
% Outputs:
%   eigen - Structure matching bct.schema.eigenmodes:
%           .Attributes     - Group-level metadata
%             .path         - "/eigenmodes"
%             .schema       - "bct.manifold.eigenmodes@1.0.0"
%             .package      - "bct"
%             .numModes     - Number of modes (k)
%             .numVertices  - Number of vertices (N)
%             .operator     - "Laplace-Beltrami"
%             .basis        - "P1-FEM"
%             .ordering     - "ascending"
%             .massType     - Mass matrix type used
%             .removedDC    - Whether DC mode was removed
%           .eigenvalues    - Dataset with .value [k×1] and .attributes
%           .eigenvectors   - Dataset with .value [N×k] and .attributes
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
%   The eigenvectors are M-orthonormal: eigenvectors' * M * eigenvectors = I
%   Eigenvalues are returned in ascending order: λ₀ ≤ λ₁ ≤ ... ≤ λₖ
%
%   By default, all modes including the DC (constant) mode are kept.
%   Set 'RemoveDC' to true to exclude the smallest eigenvalue mode.
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
%   Returns schema-compliant structure matching bct.schema.eigenmodes
%   for consistent validation and future serialization.
%
% Examples:
%   % Manifold-based usage
%   eigen = bct.manifold.eigenmodes(M, 100);
%   eigenvalues = eigen.eigenvalues.value;
%   eigenvectors = eigen.eigenvectors.value;
%   k = eigen.Attributes.numModes;
%
%   % Matrix-based usage (standalone)
%   [~, K] = bct.manifold.operator.stiffness(M);
%   Mass = bct.manifold.operator.mass(M);
%   eigen = bct.manifold.eigenmodes(K, Mass, 100);
%
%   % Remove DC mode
%   eigen = bct.manifold.eigenmodes(M, 100, 'RemoveDC', true);
%
%   % Use barycentric mass matrix (Manifold-based only)
%   eigen = bct.manifold.eigenmodes(M, 100, 'MassType', 'barycentric');
%
%   % Project signal onto eigenmodes
%   eigen = bct.manifold.eigenmodes(M, 100);
%   Mass = M.massmatrix();
%   coeffs = eigen.eigenvectors.value' * Mass * signal;  % Spectral coefficients
%   reconstructed = eigen.eigenvectors.value * coeffs;    % Reconstruct signal
%
%   % Spectral filtering (heat kernel)
%   tau = 10;
%   heat_kernel = exp(-eigen.eigenvalues.value * tau);
%   filtered = eigen.eigenvectors.value * (heat_kernel .* coeffs);
%
% See also: bct.schema.eigenmodes, bct.manifold.operator.mass, 
%           bct.manifold.operator.stiffness, bct.manifold.eigen.solve

% Parse input arguments to determine mode
if nargin >= 1 && isa(varargin{1}, 'bct.Manifold')
    % Manifold-based mode
    p = inputParser;
    p.addRequired('Manifold', @(x) isa(x, 'bct.Manifold'));
    p.addRequired('numModes', @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('RemoveDC', false, @islogical);
    p.addParameter('MassType', "voronoi", @(x) isstring(x) || ischar(x));
    p.addParameter('EigsOpts', struct(), @isstruct);
    p.parse(varargin{:});
    
    Manifold = p.Results.Manifold;
    numModes = p.Results.numModes;
    removeDC = p.Results.RemoveDC;
    massType = string(p.Results.MassType);
    eigsOpts = p.Results.EigsOpts;
    
    % Get FEM matrices from manifold (uses caching)
    stiffnessData = Manifold.stiffness('variant', 'cotan', 'sign', 'positive', 'symmetrize', true);
    K = stiffnessData.value;
    
    massData = Manifold.mass('variant', massType);
    M = massData.value;
    
    % Get number of vertices for schema
    numVertices = Manifold.numVertices();
    
elseif nargin >= 3 && (issparse(varargin{1}) || ismatrix(varargin{1})) && ...
                      (issparse(varargin{2}) || ismatrix(varargin{2}))
    % Matrix-based mode
    p = inputParser;
    p.addRequired('K', @(x) (issparse(x) || ismatrix(x)) && ismatrix(x));
    p.addRequired('M', @(x) (issparse(x) || ismatrix(x)) && ismatrix(x));
    p.addRequired('numModes', @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('RemoveDC', false, @islogical);
    p.addParameter('EigsOpts', struct(), @isstruct);
    p.parse(varargin{:});
    
    K = p.Results.K;
    M = p.Results.M;
    numModes = p.Results.numModes;
    removeDC = p.Results.RemoveDC;
    eigsOpts = p.Results.EigsOpts;
    massType = "unknown";  % Matrix-based mode doesn't track mass type
    
    % Validate matrix dimensions
    assert(size(K, 1) == size(K, 2), 'Stiffness matrix K must be square');
    assert(size(M, 1) == size(M, 2), 'Mass matrix M must be square');
    assert(size(K, 1) == size(M, 1), 'K and M must have same dimensions');
    
    % Infer number of vertices from matrix size
    numVertices = size(M, 1);
    
else
    error('bct:manifold:eigenmodes:InvalidInput', ...
        ['Invalid input arguments.\n' ...
         'Usage:\n' ...
         '  eigen = bct.manifold.eigenmodes(Manifold, k, ...)\n' ...
         '  eigen = bct.manifold.eigenmodes(K, Mass, k, ...)']);
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

% Build schema-compliant structure
eigen = struct();

% Group-level attributes (metadata)
eigen.attributes = struct();
eigen.attributes.schema = 'bct.manifold.eigen@1.0.0';
eigen.attributes.package = 'bct.manifold.eigen';
eigen.attributes.numModes = uint32(length(eigenvalues));
eigen.attributes.numVertices = uint32(numVertices);
eigen.attributes.operator = "Laplace-Beltrami";
eigen.attributes.basis = "P1-FEM";
eigen.attributes.ordering = "ascending";
eigen.attributes.massType = massType;
eigen.attributes.removedDC = removeDC;

% Datasets (each with .value and .attributes)
eigen.eigenvalues = struct();
eigen.eigenvalues.value = eigenvalues;
eigen.eigenvalues.attributes = struct();
eigen.eigenvalues.attributes.name = 'eigenvalues';
eigen.eigenvalues.attributes.path = 'eigen/eigenvalues';
eigen.eigenvalues.attributes.description = 'Eigenvalues of Laplace-Beltrami operator';
eigen.eigenvalues.attributes.shape = [length(eigenvalues), 1];
eigen.eigenvalues.attributes.dtype = 'float64';
eigen.eigenvalues.attributes.units = '1/area';

eigen.eigenvectors = struct();
eigen.eigenvectors.value = eigenvectors;
eigen.eigenvectors.attributes = struct();
eigen.eigenvectors.attributes.name = 'eigenvectors';
eigen.eigenvectors.attributes.path = 'eigen/eigenvectors';
eigen.eigenvectors.attributes.description = 'Eigenvectors (modes) of Laplace-Beltrami operator (M-orthonormal)';
eigen.eigenvectors.attributes.shape = [numVertices, length(eigenvalues)];
eigen.eigenvectors.attributes.dtype = 'float64';
eigen.eigenvectors.attributes.orthonormality = 'mass-weighted';

% Report
fprintf('bct.manifold.eigenmodes: Eigendecomposition complete\n');
fprintf('  Requested modes: %d\n', numModes);
fprintf('  Retained modes:  %d\n', eigen.attributes.numModes);
fprintf('  Eigenvalue range: [%.6f, %.6f]\n', min(eigenvalues), max(eigenvalues));

end
