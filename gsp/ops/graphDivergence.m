function divG = graphDivergence(G, edgeField, varargin)
% GRAPHDIVERGENCE Compute graph divergence operator div_G applied to edge field
%
% divG = graphDivergence(G, edgeField) computes the vertex-wise divergence
% of an edge field on graph G. The divergence is the adjoint of the gradient
% operator: div_G = -∇G*.
%
% divG = graphDivergence(G, edgeField, 'param', value, ...) specifies options:
%   'EdgeWeights' - 'normalized' (default), 'uniform', or 'none'
%   'EdgeList'    - custom edge list [Ne x 2] (default: from adjacency)
%   'Directed'    - true/false for directed graph (default: false)
%
% Input:
%   G         - GSPBOX graph structure with weight matrix .W
%   edgeField - Field on edges (Ne x T matrix, or Ne x 1 vector)
%
% Output:
%   divG - Divergence at vertices (N x T matrix, or N x 1 vector)
%
% Mathematical Definition:
%   The graph divergence is the adjoint of the graph gradient:
%   <∇G x, y> = <x, -div_G y>
%
%   For vertex i:
%   (div_G f)_i = -∑_{j∈N(i)} sqrt(w_ij) * f_ij
%
%   where f_ij is the edge field value on edge (i,j) and N(i) are neighbors of i.
%
% Example:
%   % Compute divergence of gradient (should approximate Laplacian)
%   G = fromCortex(vertices, faces);
%   x = randn(G.N, 1);
%   gradX = graphGradient(G, x);
%   divGradX = graphDivergence(G, gradX);
%   
%   % Compare with Laplacian: should be approximately -G.L * x
%   laplacianX = -G.L * x;
%   error = norm(divGradX - laplacianX) / norm(laplacianX);
%   fprintf('Relative error: %.2e\n', error);
%
% References:
%   Adjoint relationship from discrete calculus on graphs:
%   Shuman et al. "The emerging field of signal processing on graphs" (2013)
%   
%   The negative sign ensures: ∇G* = -div_G, so that:
%   div_G(∇G x) = -G.L * x (discrete Laplacian)
%
% See also: graphGradient, graphTotalVariation

% Input validation
if nargin < 2
    error('Graph structure G and edge field are required');
end

if ~isstruct(G) || ~isfield(G, 'W')
    error('G must be a graph structure with weight matrix W');
end

if ~isnumeric(edgeField)
    error('Edge field must be numeric');
end

% Parse options
p = inputParser;
addParameter(p, 'EdgeWeights', 'normalized', @(s) ismember(s, {'normalized', 'uniform', 'none'}));
addParameter(p, 'EdgeList', [], @(e) isempty(e) || (isnumeric(e) && size(e,2) == 2));
addParameter(p, 'Directed', false, @islogical);
parse(p, varargin{:});

opts = p.Results;

% Get dimensions
[Ne, T] = size(edgeField);
N = G.N;

% Build edge list if not provided
if isempty(opts.EdgeList)
    W = G.W;
    if ~opts.Directed
        % For undirected graphs, use upper triangular part
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
        idx1 = sub2ind(size(G.W), edges(:,1), edges(:,2));
        idx2 = sub2ind(size(G.W), edges(:,2), edges(:,1));
        weights1 = full(G.W(idx1));
        weights2 = full(G.W(idx2));
        weights = max(weights1, weights2);
    end
end

if size(edges, 1) ~= Ne
    error('Edge field size (%d) does not match number of edges (%d)', Ne, size(edges, 1));
end

% Apply edge weighting scheme
switch opts.EdgeWeights
    case 'normalized'
        edge_weights = sqrt(abs(weights));
    case 'uniform'
        edge_weights = ones(Ne, 1);
    case 'none'
        edge_weights = ones(Ne, 1);
end

% Compute divergence
if T == 1
    % Single time point
    divG = computeDivergenceSingle(edgeField, edges, edge_weights, N, opts.Directed);
else
    % Multiple time points
    divG = zeros(N, T);
    for t = 1:T
        divG(:, t) = computeDivergenceSingle(edgeField(:, t), edges, edge_weights, N, opts.Directed);
    end
end

end

function div = computeDivergenceSingle(f, edges, weights, N, isDirected)
% Compute divergence for single time point
% For undirected: (div f)_i = -∑_{j∈N(i)} sqrt(w_ij) * f_ij
% The negative sign ensures div = -∇* (adjoint of gradient)

i_vertices = edges(:, 1);
j_vertices = edges(:, 2);

% Initialize divergence vector
div = zeros(N, 1);

% Weight edge field values
weighted_f = weights .* f;

if isDirected
    % For directed graphs: accumulate incoming and outgoing edges separately
    % Incoming edges to vertex j contribute positively
    for k = 1:length(j_vertices)
        div(j_vertices(k)) = div(j_vertices(k)) + weighted_f(k);
    end
    
    % Outgoing edges from vertex i contribute negatively  
    for k = 1:length(i_vertices)
        div(i_vertices(k)) = div(i_vertices(k)) - weighted_f(k);
    end
    
else
    % For undirected graphs: each edge contributes to both endpoints
    % Edge (i,j) with field value f_ij contributes:
    % +f_ij to vertex j (incoming)
    % -f_ij to vertex i (outgoing)
    
    for k = 1:length(edges)
        i = i_vertices(k);
        j = j_vertices(k);
        contribution = weighted_f(k);
        
        % Contribution to vertex j (positive)
        div(j) = div(j) + contribution;
        
        % Contribution to vertex i (negative)
        div(i) = div(i) - contribution;
    end
end

% Apply negative sign for adjoint relationship: div_G = -∇G*
div = -div;

end