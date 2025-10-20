function G = fromCortex(V, F, varargin)
% FROMCORTEX Create GSPBOX graph from cortical surface mesh
%
% G = fromCortex(V, F) creates a GSPBOX graph structure from vertices V
% and faces F using geodesic distance weighting.
%
% G = fromCortex(V, F, opts) specifies options:
%   'WeightType'     - 'geodesic' (default), 'cotangent', or 'uniform'
%   'NormalizedLap'  - true (default) or false for Laplacian type
%   'Sigma'          - bandwidth parameter for Gaussian weights (default: auto)
%   'MaxConnections' - maximum connections per vertex (default: inf)
%   'Verbose'        - true/false for progress output (default: false)
%
% Returns:
%   G - GSPBOX graph structure with fields:
%     .W   - Weight matrix (sparse N x N)
%     .A   - Adjacency matrix (sparse N x N, binary)
%     .L   - Laplacian matrix (sparse N x N)
%     .N   - Number of vertices
%     .Ne  - Number of edges
%     .coords - Vertex coordinates (N x 3)
%     .type   - Graph type string
%     .sigma  - Bandwidth parameter used
%
% Example:
%   % Basic usage with geodesic weights
%   G = meg_gsp.graph.fromCortex(vertices, faces);
%   
%   % Cotangent weights for smoother Laplacian
%   opts.WeightType = 'cotangent';
%   opts.NormalizedLap = true;
%   G = meg_gsp.graph.fromCortex(vertices, faces, opts);
%
% References:
%   Graph construction follows GSPBOX conventions. Cotangent weights
%   implement discrete Laplace-Beltrami operator as in:
%   Desbrun et al. "Implicit fairing of irregular meshes using diffusion 
%   and curvature flow" (1999)
%
% See also: ensureLaplacian, gsp_graph

% Input validation
if nargin < 2
    error('Vertices and faces are required inputs');
end

if size(V, 2) ~= 3
    error('Vertices must be N x 3 matrix');
end

if size(F, 2) ~= 3
    error('Faces must be F x 3 matrix');
end

% Parse options
if nargin >= 3 && isstruct(varargin{1})
    opts = varargin{1};
else
    opts = struct();
    for i = 1:2:length(varargin)
        opts.(varargin{i}) = varargin{i+1};
    end
end

% Set defaults
if ~isfield(opts, 'WeightType'), opts.WeightType = 'geodesic'; end
if ~isfield(opts, 'NormalizedLap'), opts.NormalizedLap = true; end
if ~isfield(opts, 'Sigma'), opts.Sigma = []; end
if ~isfield(opts, 'MaxConnections'), opts.MaxConnections = inf; end
if ~isfield(opts, 'Verbose'), opts.Verbose = false; end

N = size(V, 1);

if opts.Verbose
    fprintf('Building cortical graph: %d vertices, %d faces\n', N, size(F, 1));
    fprintf('Weight type: %s\n', opts.WeightType);
end

% Build adjacency from face connectivity
A = buildFaceAdjacency(V, F, opts);

% Compute edge weights
switch lower(opts.WeightType)
    case 'uniform'
        W = A;
        
    case 'geodesic'
        W = computeGeodesicWeights(V, F, A, opts);
        
    case 'cotangent'
        W = computeCotangentWeights(V, F, A, opts);
        
    otherwise
        error('Unknown weight type: %s', opts.WeightType);
end

% Ensure symmetry
W = (W + W') / 2;

% Apply maximum connections constraint
if opts.MaxConnections < inf
    W = enforceMaxConnections(W, opts.MaxConnections, opts);
end

% Create GSPBOX graph structure
G = struct();
G.W = W;
G.A = (W > 0);
G.N = N;
G.Ne = nnz(G.A) / 2;  % Undirected edges
G.coords = V;
G.type = sprintf('cortical_%s', opts.WeightType);

% Compute Laplacian
G = ensureLaplacian(G, struct('NormalizedLap', opts.NormalizedLap));

% Store parameters
G.sigma = opts.Sigma;
G.lap_type = opts.NormalizedLap;

if opts.Verbose
    fprintf('Graph created: %d edges, spectral radius: %.3f\n', ...
            G.Ne, full(max(real(eigs(G.L, 1, 'largestreal')))));
end

end

function A = buildFaceAdjacency(V, F, opts)
% Build binary adjacency matrix from face connectivity
N = size(V, 1);
nF = size(F, 1);

if opts.Verbose
    fprintf('  Building face adjacency...\n');
end

% Pre-allocate edge list
edges = zeros(3 * nF, 2);
idx = 1;

% Extract edges from each face
for i = 1:nF
    face = F(i, :);
    % Add edges: (v1,v2), (v2,v3), (v3,v1)
    edges(idx:idx+2, :) = [face(1), face(2); 
                           face(2), face(3); 
                           face(3), face(1)];
    idx = idx + 3;
end

% Remove duplicate edges and self-loops
edges = unique(sort(edges, 2), 'rows');
edges = edges(edges(:,1) ~= edges(:,2), :);

% Create sparse adjacency matrix
A = sparse(edges(:,1), edges(:,2), 1, N, N);
A = A + A';  % Make symmetric
A = (A > 0);  % Binarize

end

function W = computeGeodesicWeights(V, ~, A, opts)
% Compute weights based on geodesic distances
N = size(V, 1);

if opts.Verbose
    fprintf('  Computing geodesic weights...\n');
end

% Use Euclidean distance as approximation for local geodesic
[i, j] = find(triu(A));
nEdges = length(i);

weights = zeros(nEdges, 1);
for k = 1:nEdges
    weights(k) = norm(V(i(k), :) - V(j(k), :));
end

% Auto-select sigma if not provided
if isempty(opts.Sigma)
    opts.Sigma = mean(weights);
end

% Gaussian kernel: w_ij = exp(-d_ij^2 / (2*sigma^2))
weights = exp(-weights.^2 / (2 * opts.Sigma^2));

% Create symmetric weight matrix
W = sparse(i, j, weights, N, N);
W = W + W';

end

function W = computeCotangentWeights(V, F, ~, opts)
% Compute cotangent weights for discrete Laplace-Beltrami operator
N = size(V, 1);
nF = size(F, 1);

if opts.Verbose
    fprintf('  Computing cotangent weights...\n');
end

% Initialize weight matrix
W = sparse(N, N);

% Process each face to compute cotangent weights
for fIdx = 1:nF
    face = F(fIdx, :);
    v1 = face(1); v2 = face(2); v3 = face(3);
    
    % Get vertex coordinates
    p1 = V(v1, :); p2 = V(v2, :); p3 = V(v3, :);
    
    % Compute edge vectors
    e1 = p2 - p3;  % opposite to vertex 1
    e2 = p3 - p1;  % opposite to vertex 2  
    e3 = p1 - p2;  % opposite to vertex 3
    
    % Compute cotangent of angles
    cot1 = computeCotangent(e2, -e3);  % angle at vertex 1
    cot2 = computeCotangent(e3, -e1);  % angle at vertex 2
    cot3 = computeCotangent(e1, -e2);  % angle at vertex 3
    
    % Add cotangent weights (symmetric)
    % Edge (v2,v3) gets weight from cotangent at v1
    W(v2, v3) = W(v2, v3) + cot1;
    W(v3, v2) = W(v3, v2) + cot1;
    
    % Edge (v1,v3) gets weight from cotangent at v2
    W(v1, v3) = W(v1, v3) + cot2;
    W(v3, v1) = W(v3, v1) + cot2;
    
    % Edge (v1,v2) gets weight from cotangent at v3
    W(v1, v2) = W(v1, v2) + cot3;
    W(v2, v1) = W(v2, v1) + cot3;
end

% Divide by 2 (each edge contributes from two adjacent faces)
W = W / 2;

% Clamp negative weights to small positive values
W = max(W, 1e-8 * speye(N));

end

function cot_angle = computeCotangent(u, v)
% Compute cotangent of angle between vectors u and v
% cot(θ) = cos(θ)/sin(θ) = dot(u,v) / norm(cross(u,v))

dot_uv = dot(u, v);
cross_uv = cross(u, v);
norm_cross = norm(cross_uv);

if norm_cross < 1e-10
    % Degenerate case: vectors are parallel
    cot_angle = 0;
else
    cot_angle = dot_uv / norm_cross;
end

% Clamp to reasonable range
cot_angle = max(min(cot_angle, 1e6), -1e6);

end

function W = enforceMaxConnections(W, maxConn, opts)
% Limit number of connections per vertex by keeping strongest weights
[N, ~] = size(W);

if opts.Verbose
    fprintf('  Enforcing max %d connections per vertex...\n', maxConn);
end

for i = 1:N
    % Get connections for vertex i
    [neighbors, ~, weights] = find(W(i, :));
    
    if length(neighbors) > maxConn
        % Sort by weight strength and keep top connections
        [~, sortIdx] = sort(abs(weights), 'descend');
        keepIdx = sortIdx(1:maxConn);
        
        % Zero out weak connections
        W(i, :) = 0;
        W(i, neighbors(keepIdx)) = weights(keepIdx);
    end
end

% Ensure symmetry after pruning
W = (W + W') / 2;

end