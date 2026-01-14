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
%   out - Structure with fields:
%     .lengths  - [Ne×1] Length of each undirected edge
%     .weights  - Structure with .cotangent and .euclidean weights
%     .header   - Metadata about computation options
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
%   lengths = edgeGeom.lengths;
%   cotangentWeights = edgeGeom.weights.cotangent;
%   euclideanWeights = edgeGeom.weights.euclidean;
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

% Initialize output structure
out = struct();
out.header = struct('precision', precision);

% Compute edge lengths
[lengthHeader, out.lengths] = bct.manifold.geometry.edge.lengths(meshInput, ...
    'precision', precision);
out.header.lengths = lengthHeader;

% Compute edge weights
[weightsHeader, out.weights] = bct.manifold.geometry.edge.weights(meshInput);
out.header.weights = weightsHeader;

end
