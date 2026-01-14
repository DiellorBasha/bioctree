function F = heatadvection(from, to, M, tau, varargin)
%HEATADVECTION Create time-varying heat field advecting along shortest path
%
% Syntax:
%   F = bct.field.generate.heatadvection(from, to, M, tau)
%   F = bct.field.generate.heatadvection(from, to, M, tau, 'Normalize', true)
%   F = bct.field.generate.heatadvection(from, to, M, tau, 'Metric', 'cotangent')
%
% Inputs:
%   from - Source vertex index
%   to   - Target vertex index
%   M    - bct.Manifold object (must have eigenmodes computed)
%   tau  - Heat kernel time parameter (controls diffusion width)
%
% Optional Parameters:
%   'Normalize' - Normalize each heat field to [0,1] (default: true)
%   'Metric'    - Distance metric for shortest path: 'cotangent' (default) | 'euclidean'
%
% Outputs:
%   F - Field struct with:
%       .support   = 'vertex'
%       .valueType = 'scalar'
%       .value     = [nV × nT] matrix where nT is number of path vertices
%       .time      = [1 × nT] vector of time indices (1, 2, 3, ...)
%       .meta      - Metadata including path information
%
% Description:
%   Creates a time-varying field by computing the shortest path between two
%   vertices and generating a heat kernel field at each vertex along the path.
%   The result is a matrix where each column is a heat field centered at one
%   vertex in the path sequence.
%
%   This simulates heat "advecting" (moving) along the shortest path from the
%   source to target vertex. Useful for:
%   - Visualizing geodesic paths on manifolds
%   - Creating spatiotemporal patterns for analysis
%   - Testing time-varying field operators
%   - Path-based signal generation
%
%   The tau parameter controls the spatial spread of each heat kernel:
%   - Small tau (1-10) → sharply localized along path
%   - Medium tau (10-100) → moderate diffusion around path
%   - Large tau (100-1000) → broad diffusion, path less distinct
%
% Examples:
%   % Create heat advection field along shortest path
%   M = bct.manifold.load();
%   M.eigenmodes(100);
%   F = bct.field.generate.heatadvection(100, 500, M, 20);
%   
%   % Access time-varying field values
%   nTimePoints = size(F.value, 2);
%   firstFrame = F.value(:, 1);    % Heat at source
%   lastFrame = F.value(:, end);   % Heat at target
%   
%   % Create with euclidean distance metric
%   F = bct.field.generate.heatadvection(100, 500, M, 20, 'Metric', 'euclidean');
%   
%   % Create without normalization
%   F = bct.field.generate.heatadvection(100, 500, M, 20, 'Normalize', false);
%
% See also: bct.field.generate.heat, bct.Manifold.shortestPath, 
%           bct.manifold.query.shortestPath

% Parse optional arguments
p = inputParser();
p.addParameter('Normalize', true, @islogical);
p.addParameter('Metric', 'cotangent', @(x) ismember(x, {'cotangent', 'euclidean'}));
p.parse(varargin{:});

normalize = p.Results.Normalize;
metric = p.Results.Metric;

% Validate inputs
if ~isa(M, 'bct.Manifold')
    error('bct:field:generate:heatadvection:InvalidManifold', ...
        'M must be a bct.Manifold object');
end

nV = M.numVertices();

if from < 1 || from > nV || round(from) ~= from
    error('bct:field:generate:heatadvection:InvalidFrom', ...
        'from must be a valid vertex index (1 to %d)', nV);
end

if to < 1 || to > nV || round(to) ~= to
    error('bct:field:generate:heatadvection:InvalidTo', ...
        'to must be a valid vertex index (1 to %d)', nV);
end

if tau <= 0
    error('bct:field:generate:heatadvection:InvalidTau', ...
        'tau must be positive');
end

% Compute shortest path between vertices
try
    [pathIndices, pathDist] = M.shortestPath(from, to, 'Metric', metric);
catch ME
    error('bct:field:generate:heatadvection:ShortestPathFailed', ...
        'Failed to compute shortest path: %s', ME.message);
end

% Number of time points = number of vertices in path
nT = numel(pathIndices);

if nT == 0
    error('bct:field:generate:heatadvection:EmptyPath', ...
        'Shortest path returned empty (no path exists between vertices)');
end

% Pre-allocate matrix for time-varying field values
fieldValues = zeros(nV, nT);

% Generate heat field at each vertex along the path
for i = 1:nT
    % Get current vertex index in path
    vertexIdx = pathIndices(i);
    
    % Generate heat field centered at this vertex
    heatField = bct.field.generate.heat(M, vertexIdx, tau, 'Normalize', normalize);
    
    % Store as column in matrix
    fieldValues(:, i) = heatField.value;
end

% Build field struct with time-varying data
F = struct();
F.schemaVersion = 'bct.field@1';
F.meshId = char(M.ID);
F.support = 'vertex';
F.valueType = 'scalar';
F.value = fieldValues;              % [nV × nT] matrix
F.time = 1:nT;                      % Time indices corresponding to path sequence
F.meta = struct(...
    'generator', 'heatadvection', ...
    'fromVertex', from, ...
    'toVertex', to, ...
    'tau', tau, ...
    'metric', metric, ...
    'pathLength', nT, ...
    'pathDistance', pathDist, ...
    'pathIndices', pathIndices, ...
    'normalized', normalize, ...
    'numModes', numel(M.eigenvalues()));

end
