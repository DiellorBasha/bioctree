function gradG = graphGradient(G, x, varargin)
% GRAPHGRADIENT Compute graph gradient operator ∇G applied to signal x
%
% gradG = graphGradient(G, x) computes the edge-wise gradient of signal x
% on graph G. The gradient assigns to each edge the weighted difference
% between connected vertices.
%
% gradG = graphGradient(G, x, 'param', value, ...) specifies options:
%   'EdgeWeights' - 'normalized' (default), 'uniform', or 'none'
%   'Directed'    - true/false to compute directed gradient (default: false)
%   'EdgeList'    - custom edge list [Ne x 2] (default: from adjacency)
%
% Input:
%   G - GSPBOX graph structure with fields .W (weight matrix), .N (number of vertices)
%   x - Signal on vertices (N x T matrix, or N x 1 vector)
%
% Output:
%   gradG - Edge gradient values (Ne x T matrix, or Ne x 1 vector)
%           For edge (i,j): gradG_ij = sqrt(W_ij) * (x_j - x_i)
%
% Mathematical Definition:
%   The graph gradient ∇G is the discrete analogue of the spatial gradient.
%   For each edge e = (i,j) with weight w_ij:
%   
%   (∇G x)_e = sqrt(w_ij) * (x_j - x_i)
%
%   This definition ensures the adjoint relationship:
%   <∇G x, y> = <x, ∇G* y> = <x, div_G y>
%
% Example:
%   % Compute gradient of smooth signal on cortical graph
%   G = meg_gsp.graph.fromCortex(vertices, faces);
%   signal = randn(G.N, 100);  % Random signal
%   gradG = meg_gsp.ops.graphGradient(G, signal);
%   
%   % Visualize gradient magnitude
%   gradMag = sqrt(sum(gradG.^2, 1));  % L2 norm over edges
%   meg_gsp.viz.plotCortexMap(vertices, faces, gradMag);
%
% References:
%   Definition follows discrete calculus on graphs from:
%   Shuman et al. "The emerging field of signal processing on graphs" (2013)
%   Grassi et al. "A Time-Vertex Signal Processing Framework" (2017)
%
% See also: graphDivergence, graphTotalVariation, meg_gsp.ops.timeDiff

% Input validation
if nargin < 2
    error('Graph structure G and signal x are required');
end

if ~isstruct(G) || ~isfield(G, 'W')
    error('G must be a graph structure with weight matrix W');
end

if ~isnumeric(x) || size(x, 1) ~= G.N
    error('Signal x must be numeric with %d rows (number of vertices)', G.N);
end

% Parse options
p = inputParser;
addParameter(p, 'EdgeWeights', 'normalized', @(s) ismember(s, {'normalized', 'uniform', 'none'}));
addParameter(p, 'Directed', false, @islogical);
addParameter(p, 'EdgeList', [], @(e) isempty(e) || (isnumeric(e) && size(e,2) == 2));
parse(p, varargin{:});

opts = p.Results;

% Get signal dimensions
[N, T] = size(x);
if N ~= G.N
    error('Signal dimension mismatch: expected %d vertices, got %d', G.N, N);
end

% Build edge list if not provided
if isempty(opts.EdgeList)
    W = G.W;
    if ~opts.Directed
        % For undirected graphs, use upper triangular part to avoid duplicates
        [i, j, weights] = find(triu(W));
    else
        % For directed graphs, use all edges
        [i, j, weights] = find(W);
    end
    edges = [i, j];
else
    edges = opts.EdgeList;
    % Extract weights for custom edge list
    if opts.Directed
        idx = sub2ind(size(G.W), edges(:,1), edges(:,2));
        weights = full(G.W(idx));
    else
        % For undirected, ensure consistent weight extraction
        idx1 = sub2ind(size(G.W), edges(:,1), edges(:,2));
        idx2 = sub2ind(size(G.W), edges(:,2), edges(:,1));
        weights1 = full(G.W(idx1));
        weights2 = full(G.W(idx2));
        weights = max(weights1, weights2);  % Use maximum (should be equal for symmetric W)
    end
end

Ne = size(edges, 1);

% Apply edge weighting scheme
switch opts.EdgeWeights
    case 'normalized'
        % Standard definition: sqrt(w_ij) * (x_j - x_i)
        edge_weights = sqrt(abs(weights));
        
    case 'uniform'
        % Uniform weighting: all edges have weight 1
        edge_weights = ones(Ne, 1);
        
    case 'none'
        % No weighting: just differences
        edge_weights = ones(Ne, 1);
end

% Compute gradient for each time point
if T == 1
    % Single time point - vectorized computation
    gradG = computeGradientSingle(x, edges, edge_weights);
else
    % Multiple time points - loop over time (more memory efficient)
    gradG = zeros(Ne, T);
    for t = 1:T
        gradG(:, t) = computeGradientSingle(x(:, t), edges, edge_weights);
    end
end

end

function grad = computeGradientSingle(x, edges, weights)
% Compute gradient for single time point
% grad_e = weight_e * (x_j - x_i) for edge e = (i,j)

i_vertices = edges(:, 1);
j_vertices = edges(:, 2);

% Compute differences: x_j - x_i
differences = x(j_vertices) - x(i_vertices);

% Apply edge weights
grad = weights .* differences;

end