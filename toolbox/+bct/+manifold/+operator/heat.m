function out = heat(meshInput, varargin)
%HEAT Assemble heat operator from Manifold or mesh data
%
% Syntax:
%   heat = bct.manifold.operator.heat(M)
%   heat = bct.manifold.operator.heat(V, F)
%   heat = bct.manifold.operator.heat(..., Name, Value)
%
% Inputs:
%   M       - bct.Manifold object
%   OR
%   V       - [N×3] vertex coordinates
%   F       - [nF×3] face connectivity (1-based)
%
% Name-Value Parameters:
%   t_heat     - Heat diffusion time (default: auto-calculated as mean_edge_length^2)
%   symmetrize - Force symmetrization (default: true)
%   precision  - Output precision (default: 'double')
%                'double' - Double precision
%                'single' - Single precision
%
% Outputs:
%   out - Structure matching heat operator dataset schema:
%     .attributes - Dataset-level metadata:
%       .t_heat         - Heat diffusion time parameter
%       .t_heat_source  - How t_heat was determined ('auto' or 'manual')
%       .mean_edge_length - Mean edge length (if auto-calculated)
%       .symmetrize     - Whether symmetrization was applied
%       .precision      - Precision of output matrix
%       .path           - HDF5/Zarr path for this dataset
%       .description    - Dataset description
%     .value - [N×N] sparse heat operator matrix
%
% Description:
%   Assembles the heat operator for heat equation time-stepping:
%
%   heat = mass + t_heat * stiffness
%
%   where:
%   - mass: FEM mass matrix (area-weighted inner product)
%   - stiffness: FEM stiffness matrix (Laplace-Beltrami operator)
%   - t_heat: heat diffusion time parameter
%
%   If t_heat is not provided and input is a Manifold, it is automatically
%   calculated as:
%     h = mean(edge_lengths)
%     t_heat = h^2
%
%   This choice scales the diffusion time with the mesh resolution.
%
%   The heat operator appears in implicit time-stepping schemes:
%     (M + t*K) * u_{n+1} = M * u_n
%
%   where M is mass, K is stiffness, and t is time step.
%
% Examples:
%   % Using Manifold object (auto t_heat)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   heat = bct.manifold.operator.heat(M);
%   H = heat.value;
%
%   % Using explicit V, F with manual t_heat
%   heat = bct.manifold.operator.heat(V, F, 't_heat', 1.0);
%
%   % Custom time parameter
%   heat = bct.manifold.operator.heat(M, 't_heat', 0.5);
%
%   % Use for heat equation solver
%   heat = bct.manifold.operator.heat(M);
%   H = heat.value;
%   u_next = H \ (M.mass.value * u_current);
%
% See also: bct.manifold.operator.mass, bct.manifold.operator.stiffness

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:operator:heat:NoInput', ...
        'At least one input required: heat(M) or heat(V, F)');
end

% Check if first argument is Manifold or numeric
isManifold = false;
if isa(meshInput, 'bct.Manifold')
    % Case: heat(M, Name=Value...)
    M = meshInput;
    V = M.Vertices;
    F = M.Faces;
    nameValueStart = 1;
    isManifold = true;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: heat(V, F, Name=Value...)
    V = meshInput;
    F = varargin{1};
    nameValueStart = 2;
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:operator:heat:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:operator:heat:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:operator:heat:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:operator:heat:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:manifold:operator:heat:InvalidInput', ...
        'Input must be either heat(M) or heat(V, F). Got %s.', class(meshInput));
end

% Parse Name-Value pairs
p = inputParser;
p.addParameter('t_heat', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
p.addParameter('symmetrize', true, @islogical);
p.addParameter('precision', 'double', @(x) ismember(x, ["double","single"]));
p.parse(varargin{nameValueStart:end});

% Extract parameters
t_heat_manual = p.Results.t_heat;
symmetrize = p.Results.symmetrize;
precision = char(p.Results.precision);

% ----------------------------
% Get mass and stiffness matrices
% ----------------------------
if isManifold
    % Use cached operators from Manifold
    mass = M.mass.value;
    stiffness = M.stiffness.value;
else
    % Compute from V, F
    massOp = bct.manifold.operator.mass(V, F);
    stiffnessOp = bct.manifold.operator.stiffness(V, F);
    mass = massOp.value;
    stiffness = stiffnessOp.value;
end

% ----------------------------
% Determine t_heat
% ----------------------------
if isempty(t_heat_manual)
    % Auto-calculate from edge lengths
    t_heat_source = 'auto';
    
    if isManifold
        % Get edge geometry from Manifold (cached)
        edgeGeom = M.edgeGeometry;
        mean_edge_length = mean(edgeGeom.lengths.value);
    else
        % Compute edge lengths directly
        edgeLengthsOp = bct.manifold.geometry.edge.lengths(V, F);
        mean_edge_length = mean(edgeLengthsOp.value);
    end
    
    t_heat = mean_edge_length^2;
else
    % User-provided t_heat
    t_heat_source = 'manual';
    t_heat = t_heat_manual;
    mean_edge_length = NaN;  % Not computed
end

% ----------------------------
% Assemble heat operator
% ----------------------------
H = mass + t_heat * stiffness;

% Symmetrize if requested
if symmetrize
    H = (H + H') / 2;
end

% Convert precision if requested
if strcmp(precision, 'single')
    H = single(H);
end

% ----------------------------
% Build output structure
% ----------------------------
out = struct();

% Dataset-level attributes (metadata for this specific dataset)
out.attributes = struct();
out.attributes.name = 'heat';
out.attributes.path = 'operator/heat';
out.attributes.description = 'Heat operator (mass + t_heat * stiffness)';
out.attributes.t_heat = t_heat;
out.attributes.t_heat_source = t_heat_source;
if strcmp(t_heat_source, 'auto')
    out.attributes.mean_edge_length = mean_edge_length;
end
out.attributes.symmetrize = symmetrize;
out.attributes.precision = precision;
out.attributes.units = 'area_units';
out.attributes.shape = [size(V, 1), size(V, 1)];
out.attributes.nnz = nnz(H);
out.attributes.storage = 'sparse';
out.attributes.equation = sprintf('heat = mass + %.6g * stiffness', t_heat);
out.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% The actual dataset (sparse matrix)
out.value = H;

end
