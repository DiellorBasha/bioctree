function out = edge(meshInput, varargin)
%EDGE Compute all edge-based geometric properties
%
% Syntax:
%   edgeGeom = bct.manifold.geometry.edge(M)
%   edgeGeom = bct.manifold.geometry.edge(V, F)
%   edgeGeom = bct.manifold.geometry.edge(___, Name, Value)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Name-Value Arguments:
%   'precision' - 'double' (default) or 'single'
%
% Outputs:
%   out - Structure matching bct.manifold.geometry.edge.schema:
%     .attributes                   - Group-level metadata (computation options)
%     .lengths.value                - [Ne×1] Length of each undirected edge
%     .lengths.attributes           - Dataset metadata
%     .weights_cotangent.value      - [Ne×1] Cotangent-based edge weights
%     .weights_cotangent.attributes - Dataset metadata
%     .weights_euclidean.value      - [Ne×1] Euclidean distance-based weights
%     .weights_euclidean.attributes - Dataset metadata
%     .weights_dec.value            - [Ne×1] DEC edge weights (dual/primal ratio)
%     .weights_dec.attributes       - Dataset metadata
%
% Description:
%   Aggregator function that computes all edge-based geometric properties
%   by calling the individual functions in bct.manifold.geometry.edge.*
%
% Examples:
%   % Compute all edge geometry
%   M = bct.Manifold(V, F);
%   edgeGeom = bct.manifold.geometry.edge(M);
%   
%   % Access individual properties
%   lengths = edgeGeom.lengths.value;
%   cotangentWeights = edgeGeom.weights_cotangent.value;
%   euclideanWeights = edgeGeom.weights_euclidean.value;
%   decWeights = edgeGeom.weights_dec.value;
%   
%   % Compute with single precision
%   edgeGeom = bct.manifold.geometry.edge(M, 'precision', 'single');
%
% See also: bct.manifold.geometry.face, bct.manifold.geometry.vertex,
%           bct.manifold.geometry

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.geometry.edge';
p.KeepUnmatched = true;

if isa(meshInput, 'bct.Manifold')
    addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
    parse(p, meshInput);
else
    addRequired(p, 'V', @isnumeric);
    addRequired(p, 'F', @isnumeric);
    if isempty(varargin) || ~isnumeric(varargin{1})
        error('bct:manifold:geometry:edge:InvalidInput', ...
            'Expected edge(M) or edge(V, F)');
    end
    parse(p, meshInput, varargin{1});
    varargin = varargin(2:end);  % Remove F from varargin
end

addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
parse(p, meshInput, varargin{:});

precision = string(p.Results.precision);

% Compute edge properties
[lengthHeader, lengths] = bct.manifold.geometry.edge.lengths(meshInput, ...
    'precision', precision);
[weightsHeader, weights] = bct.manifold.geometry.edge.weights(meshInput);

% Initialize output structure matching schema
out = struct();

% Group-level attributes (matches s.group.attributes in schema)
out.attributes = struct();
out.attributes.schema = 'bct.manifold.geometry.edge@1.0.0';
out.attributes.package = 'bct.manifold.geometry.edge';
out.attributes.precision = char(precision);
out.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

nE = size(lengths, 1);

% Dataset 1: lengths
out.lengths.value = lengths;
out.lengths.attributes = struct(...
    'name', 'lengths', ...
    'path', 'geometry/edge/lengths', ...
    'description', 'Euclidean length of each edge', ...
    'shape', [nE, 1], ...
    'dtype', 'double', ...
    'units', 'm', ...
    'support', 'edge', ...
    'computedBy', 'bct.manifold.geometry.edge.lengths');

% Dataset 2: weights_cotangent
out.weights_cotangent.value = weights.cotangent;
out.weights_cotangent.attributes = struct(...
    'name', 'weights_cotangent', ...
    'path', 'geometry/edge/weights_cotangent', ...
    'description', 'Cotangent-based edge weights for FEM operators', ...
    'shape', [nE, 1], ...
    'dtype', 'double', ...
    'units', '1', ...
    'support', 'edge', ...
    'computedBy', 'bct.manifold.geometry.edge.weights');

% Dataset 3: weights_euclidean
out.weights_euclidean.value = weights.euclidean;
out.weights_euclidean.attributes = struct(...
    'name', 'weights_euclidean', ...
    'path', 'geometry/edge/weights_euclidean', ...
    'description', 'Euclidean distance-based edge weights', ...
    'shape', [nE, 1], ...
    'dtype', 'double', ...
    'units', 'm', ...
    'support', 'edge', ...
    'computedBy', 'bct.manifold.geometry.edge.weights');

% Dataset 4: weights_dec
out.weights_dec.value = weights.dec;
out.weights_dec.attributes = struct(...
    'name', 'weights_dec', ...
    'path', 'geometry/edge/weights_dec', ...
    'description', 'DEC edge weights (dual/primal length ratio)', ...
    'shape', [nE, 1], ...
    'dtype', 'double', ...
    'units', '1', ...
    'support', 'edge', ...
    'computedBy', 'bct.manifold.geometry.edge.weights');

end
