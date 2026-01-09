function eigenbasis = solve(M, k, options)
%SOLVE Compute eigendecomposition of Laplace-Beltrami operator
%
% Syntax:
%   eigenbasis = bct.eigenpairs.solve(M, k)
%   eigenbasis = bct.eigenpairs.solve(M, k, Name=Value)
%
% Inputs:
%   M - bct.Manifold object
%   k - Number of eigenmodes to compute
%
% Name-Value Arguments:
%   Method       - "FEM-P1" (default) - Eigensolve method
%   MassType     - "voronoi" (default) | "barycentric" | "full"
%   RemoveDC     - logical (default: false) - Remove DC component (first mode)
%   ReturnMass   - logical (default: false) - Include mass matrix in output
%   ReturnStiffness - logical (default: false) - Include stiffness matrix
%   Force        - logical (default: false) - Force recomputation
%
% Returns:
%   eigenbasis - Struct with fields:
%
%   Mandatory:
%     schemaVersion  - "bct.spectrum.eigenbasis@1"
%     meshId         - Unique manifold identifier
%     method         - Eigensolve method used
%     operator       - "Laplace-Beltrami"
%     massType       - Mass matrix type
%     k              - Number of modes
%     values         - [k×1] eigenvalues (ascending order)
%     vectors        - [N×k] eigenvectors (columns)
%     normalization  - "M-orthonormal"
%     ordering       - "ascending"
%     removeDC       - logical indicating if DC removed
%     provenance     - Solver metadata (timestamps, versions, settings)
%     checks         - Quality metrics (orthonormality, residuals)
%
%   Optional (if requested):
%     mass           - [N×N] sparse mass matrix
%     stiffness      - [N×N] sparse stiffness matrix
%
% Provenance Fields:
%   provenance.timestamp      - datetime of computation
%   provenance.matlabVersion  - MATLAB version string
%   provenance.bctVersion     - BCT version (if available)
%   provenance.solverMethod   - eigs method used
%   provenance.dimensions     - mesh dimensions (N, F, E)
%
% Quality Check Fields:
%   checks.orthonormError     - max |Ψ'*M*Ψ - I|
%   checks.residualNorm       - max ‖K*Ψ - M*Ψ*Λ‖
%   checks.eigenvalueRange    - [min, max] eigenvalues
%
% Examples:
%   % Basic usage
%   M = bct.Manifold(V, F);
%   basis = bct.eigenpairs.solve(M, 100);
%   
%   % With barycentric mass
%   basis = bct.eigenpairs.solve(M, 100, MassType="barycentric");
%   
%   % Remove DC component
%   basis = bct.eigenpairs.solve(M, 100, RemoveDC=true);
%   
%   % Include matrices for inspection
%   basis = bct.eigenpairs.solve(M, 100, ReturnMass=true, ReturnStiffness=true);
%   
%   % Access results
%   eigenvalues = basis.values;
%   eigenvectors = basis.vectors;
%   spatial_freqs = sqrt(basis.values);
%
% See also: bct.FEM.eigenpairs, bct.Eigenpairs, bct.fem.eigensolve

arguments
    M (1,1) bct.Manifold
    k (1,1) double {mustBePositive, mustBeInteger}
    options.Method (1,1) string = "FEM-P1"
    options.MassType (1,1) string {mustBeMember(options.MassType, ["voronoi","barycentric","full"])} = "voronoi"
    options.RemoveDC (1,1) logical = false
    options.ReturnMass (1,1) logical = false
    options.ReturnStiffness (1,1) logical = false
    options.Force (1,1) logical = false
end

% =========================================================================
% Record start time
% =========================================================================
startTime = datetime('now');

% =========================================================================
% Create FEM representation
% =========================================================================
fem = bct.FEM(M, MassType=options.MassType);

% =========================================================================
% Compute eigenpairs
% =========================================================================
% Note: bct.Eigenpairs already removes DC by default, so we need to handle this
E = fem.eigenpairs(k, Force=options.Force);

% E.Values and E.Vectors already have DC removed (if it was near-zero)
% Check if we got exactly k modes
if length(E.Values) == k
    % Got exactly what we asked for
    values = E.Values;
    vectors = E.Vectors;
    actuallyRemovedDC = false;
elseif length(E.Values) == k-1
    % DC was auto-removed by bct.Eigenpairs
    values = E.Values;
    vectors = E.Vectors;
    actuallyRemovedDC = true;
else
    % Unexpected case
    values = E.Values;
    vectors = E.Vectors;
    actuallyRemovedDC = (length(E.Values) < k);
end

% Apply user's RemoveDC preference
if options.RemoveDC && ~actuallyRemovedDC
    % User wants DC removed but it's still there
    % (This means first eigenvalue was not near-zero)
    values = values(2:end);
    vectors = vectors(:, 2:end);
    actuallyRemovedDC = true;
elseif ~options.RemoveDC && actuallyRemovedDC
    % User wants DC kept but it was removed
    % We cannot add it back, so warn and proceed
    warning('bct:eigenpairs:solve', ...
        'DC component was automatically removed (eigenvalue < 1e-12). Cannot restore it.');
end

% =========================================================================
% Quality checks
% =========================================================================
checks = computeQualityChecks(vectors, values, fem.Mass, fem.Stiffness);

% =========================================================================
% Provenance metadata
% =========================================================================
provenance = struct();
provenance.timestamp = startTime;
provenance.computeTime = seconds(datetime('now') - startTime);
provenance.matlabVersion = version;

% Try to get BCT version if available
try
    provenance.bctVersion = "dev";  % TODO: Read from version file
catch
    provenance.bctVersion = "unknown";
end

provenance.solverMethod = "eigs";
provenance.dimensions = struct(...
    'numVertices', M.numVertices(), ...
    'numFaces', M.numFaces(), ...
    'numEdges', M.numEdges());

% Solver settings
provenance.settings = struct(...
    'method', options.Method, ...
    'massType', options.MassType, ...
    'k', k, ...
    'removeDC', options.RemoveDC);

% =========================================================================
% Assemble eigenbasis struct
% =========================================================================
eigenbasis = struct();

% Schema and identifiers
eigenbasis.schemaVersion = "bct.spectrum.eigenbasis@1";
eigenbasis.meshId = M.ID;
eigenbasis.method = options.Method;
eigenbasis.operator = "Laplace-Beltrami";
eigenbasis.massType = options.MassType;

% Eigendata
eigenbasis.k = length(values);
eigenbasis.values = values;
eigenbasis.vectors = vectors;

% Normalization and ordering guarantees
eigenbasis.normalization = "M-orthonormal";
eigenbasis.ordering = "ascending";
eigenbasis.removeDC = actuallyRemovedDC;

% Metadata
eigenbasis.provenance = provenance;
eigenbasis.checks = checks;

% Optional matrices
if options.ReturnMass
    eigenbasis.mass = fem.Mass;
end

if options.ReturnStiffness
    eigenbasis.stiffness = fem.Stiffness;
end

end

% =========================================================================
% Helper: Compute quality metrics
% =========================================================================
function checks = computeQualityChecks(Psi, Lambda, M, K)
    %COMPUTEQUALITYCHECKS Validate eigenpair quality
    
    % Orthonormality: Ψ'*M*Ψ should be identity
    MPsi = M * Psi;
    Gram = Psi' * MPsi;
    orthonormError = max(abs(Gram - eye(size(Gram))), [], 'all');
    
    % Residual: K*Ψ - M*Ψ*Λ should be near zero
    KPsi = K * Psi;
    MPsiLambda = MPsi * diag(Lambda);
    residual = KPsi - MPsiLambda;
    residualNorm = max(sqrt(sum(residual.^2, 1)));
    
    % Eigenvalue range
    eigenvalueRange = [min(Lambda), max(Lambda)];
    
    % Assemble checks struct
    checks = struct();
    checks.orthonormError = orthonormError;
    checks.residualNorm = residualNorm;
    checks.eigenvalueRange = eigenvalueRange;
    checks.passed = (orthonormError < 1e-8) && (residualNorm < 1.0);
end
