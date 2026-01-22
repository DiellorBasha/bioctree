function ops = operator(meshInput, varargin)
%OPERATOR Compute and aggregate all differential operators
%
% Syntax:
%   ops = bct.manifold.operator(M)
%   ops = bct.manifold.operator(V, F)
%   ops = bct.manifold.operator(__, Name, Value)
%
% Inputs:
%   M      - bct.Manifold object
%   V      - [N×3] vertex coordinates
%   F      - [M×3] face connectivity
%
% Optional Parameters:
%   MassVariant      - 'voronoi' (default), 'barycentric', 'full'
%   StiffnessVariant - 'cotan' (default)
%   StiffnessSign    - 'positive' (default), 'negative'
%   Symmetrize       - true (default), false
%   annotate         - false (default) or true to wrap outputs as quantity structs
%
% Outputs:
%   ops - Structure matching bct.manifold.operator.schema:
%     .attributes        - Group-level metadata
%       .schema          - "bct.manifold.operator@1.0.0"
%       .package         - "bct.manifold.operator"
%       .numVertices     - Number of vertices (uint32)
%       .numFaces        - Number of faces (uint32)
%       .numEdges        - Number of edges (uint32)
%       .massVariant     - Mass matrix type
%       .stiffnessVariant- Stiffness matrix type
%       .stiffnessSign   - Sign convention
%       .sparseFormat    - "coo" (export format for HDF5/Zarr)
%     .mass              - Dataset structure with .value and .attributes
%     .stiffness         - Dataset structure with .value and .attributes
%     .d0, .d1           - DEC exterior derivatives (datasets)
%     .dd0, .dd1         - DEC codifferentials (datasets)
%     .hd0, .hd1, .hd2   - DEC Hodge stars (datasets)
%     .hdd0, .hdd1, .hdd2 - DEC inverse Hodge stars (datasets)
%     .flatPP, .flatDP, .flatDD - DEC flat operators (datasets)
%     .sharpPD, .sharpDD - DEC sharp operators (datasets)
%     .mft               - Forward MFT (optional, if eigenmodes cached)
%     .imft              - Inverse MFT (optional, if eigenmodes cached)
%
% Description:
%   Aggregates fundamental operator computations from the bct.manifold.operator
%   subpackage. Computes FEM matrices (mass, stiffness) and optionally
%   spectral transform operators (MFT, IMFT) if eigenmodes are cached.
%
%   Returns a schema-compliant structure matching bct.manifold.operator.schema
%   for HDF5/Zarr serialization. Matrices are stored in native MATLAB sparse
%   format. The .attributes.sparseFormat field indicates that export functions
%   should convert to COO (coordinate) format for HDF5/Zarr output.
%
%   This is the main aggregator function for the operator package, similar to
%   bct.manifold.geometry() and bct.manifold.topology(). Computes and aggregates
%   all fundamental operators: FEM matrices (mass, stiffness), DEC operators
%   (14 operators from DiscreteExteriorCalculus), and optionally spectral
%   transforms (MFT, IMFT if eigenmodes are cached).
%   
%   DEC operators are always computed and placed at the top level of the
%   output structure. Derived operators (Laplace-Beltrami, gradient, divergence)
%   can be computed on-demand from the stored mass and stiffness matrices.
%
% Examples:
%   % Compute fundamental operators for a Manifold
%   M = bct.Manifold(V, F);
%   ops = bct.manifold.operator(M);
%   
%   % Access sparse matrices via dataset structures
%   Mass = ops.mass.value;          % [N×N sparse double]
%   Stiffness = ops.stiffness.value;% [N×N sparse double]
%   
%   % Access dataset metadata
%   massVariant = ops.mass.attributes.variant;
%   
%   % Apply operators
%   f = randn(M.numVertices(), 1);
%   Kf = ops.stiffness.value * f;
%   
%   % Access DEC operators (at top level)
%   d0 = ops.d0.value;      % Exterior derivative
%   grad = ops.d0.value;    % Gradient (same as d0)
%   laplacian = ops.dd0.value * ops.d0.value;  % Laplacian via DEC
%   
%   % Check if MFT/IMFT are available
%   if isfield(ops, 'mft')
%       spectrum = ops.mft * f;
%       reconstructed = ops.imft * spectrum;
%   end
%   
%   % Compute with custom parameters
%   ops = bct.manifold.operator(M, 'MassVariant', 'barycentric');
%   
%   % Direct V, F input
%   ops = bct.manifold.operator(V, F);
%
% See also: bct.manifold.operator.mass, bct.manifold.operator.stiffness,
%           bct.manifold.operator.mft, bct.manifold.operator.imft,
%           bct.manifold.operator.schema, bct.manifold.geometry,
%           bct.manifold.topology, bct.manifold.metric.annotate

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.operator';
p.addRequired('meshInput');
p.addOptional('F', []);
p.addParameter('MassVariant', 'voronoi', @(x) ischar(x) || isstring(x));
p.addParameter('StiffnessVariant', 'cotan', @(x) ischar(x) || isstring(x));
p.addParameter('StiffnessSign', 'positive', @(x) ischar(x) || isstring(x));
p.addParameter('Symmetrize', true, @islogical);
p.addParameter('annotate', false, @islogical);
p.parse(meshInput, varargin{:});

% Extract mesh data
if isa(meshInput, 'bct.Manifold')
    M = meshInput;
    V = M.Vertices;
    F = M.Faces;
elseif isnumeric(meshInput) && ~isempty(p.Results.F)
    % V, F interface
    V = meshInput;
    F = p.Results.F;
    M = bct.Manifold(V, F);
else
    error('bct:manifold:operator:InvalidInput', ...
        'Input must be bct.Manifold or (V, F) pair');
end

% Extract parameters
massVariant = string(p.Results.MassVariant);
stiffnessVariant = string(p.Results.StiffnessVariant);
stiffnessSign = string(p.Results.StiffnessSign);
symmetrize = p.Results.Symmetrize;
annotate = p.Results.annotate;

% Initialize output structure (schema-compliant)
ops = struct();

% Group-level attributes (metadata)
ops.attributes = struct();
ops.attributes.schema = 'bct.manifold.operator@1.0.0';
ops.attributes.package = 'bct.manifold.operator';
ops.attributes.numVertices = uint32(M.numVertices());
ops.attributes.numFaces = uint32(M.numFaces());
ops.attributes.numEdges = uint32(size(M.topology().edgeList, 1));
ops.attributes.massVariant = massVariant;
ops.attributes.stiffnessVariant = stiffnessVariant;
ops.attributes.stiffnessSign = stiffnessSign;
ops.attributes.sparseFormatdataset structures)
% ===============================================================

% Compute mass matrix (returns structure with .value and .attributes)
ops.mass = bct.manifold.operator.mass(M, 'variant', massVariant);

% Compute stiffness matrix (returns structure with .value and .attributes)
ops.stiffness = bct.manifold.operator.stiffness(M, ...
    'variant', stiffnessVariant, ...
    'sign', stiffnessSign, ...
    'symmetrize', symmetrize);

% ===============================================================
% DEC Operators (flattened to top level)
% ===============================================================

% Compute DEC operators and flatten to top level
try
    decOps = bct.manifold.operator.dec(M);
    
    % Flatten all DEC operators to top level (remove .dec nesting)
    ops.d0 = decOps.d0;
    ops.d1 = decOps.d1;
    ops.dd0 = decOps.dd0;
    ops.dd1 = decOps.dd1;
    ops.hd0 = decOps.hd0;
    ops.hd1 = decOps.hd1;
    ops.hd2 = decOps.hd2;
    ops.hdd0 = decOps.hdd0;
    ops.hdd1 = decOps.hdd1;
    ops.hdd2 = decOps.hdd2;
    ops.flatPP = decOps.flatPP;
    ops.flatDP = decOps.flatDP;
    ops.flatDD = decOps.flatDD;
    ops.sharpPD = decOps.sharpPD;
    ops.sharpDD = decOps.sharpDD;
catch ME
    % If DEC computation fails (e.g., DECLab not available), store error
    warning('bct:manifold:operator:DECError', ...
        'Failed to compute DEC operators: %s', ME.message);
end

% ===============================================================
% Spectral Transform Operators (optional)
% ===============================================================

% Compute MFT and IMFT if eigenmodes are cached
% These are optional operators that require spectral decomposition
if ~isempty(fieldnames(M.Cache.eigenmodes.data))
    % Get cached eigenmodes
    eigen = M.Cache.eigenmodes.data;
    
    % TODO: Update mft/imft functions to return dataset structures
    % For now, compute directly
    % Forward MFT: U' * Mass
    ops.mft = eigen.vectors' * ops.mass.value;
    
    % Inverse MFT: U (eigenvectors)
    ops.imft = eigen.vectors;
end

% NOTE: Derived operators (Laplace-Beltrami, gradient, divergence, curl)
% are NOT included in the schema-compliant output structure.
% They can be computed on-demand from DEC operators or mass/stiffness matrices.
% For example: Laplacian = dd0 * d0, Gradient = d0, Divergence = dd0.

% Apply unit annotation if requested
if annotate
    ops = bct.manifold.metric.annotate(ops, 'operator');
end
% Apply unit annotation if requested
if annotate
    ops = bct.manifold.metric.annotate(ops, 'operator');