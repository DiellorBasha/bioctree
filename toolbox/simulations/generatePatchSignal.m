function [signal, params] = generatePatchSignal(G, varargin)
% GENERATEPATCHSIGNAL Generate a patch signal on a graph with optional temporal dynamics
%
% Usage:
%   [signal, params] = generatePatchSignal(G)
%   [signal, params] = generatePatchSignal(G, 'param', value, ...)
%
% Inputs:
%   G - Graph structure with at least G.N (number of vertices)
%       Optional: G.jtv with G.jtv.T (time steps) and G.jtv.fs (sampling frequency)
%
% Parameters:
%   'patchSize'     - Initial patch size as percentage (0-1) or number of nodes
%                     Default: 0.1 (10% of nodes)
%   'patchCenter'   - Center node index or 'random' or 'auto'
%                     Default: 'auto' (finds node closest to graph center)
%   'patchValue'    - Value inside the patch (default: 1)
%   'backgroundValue' - Value outside the patch (default: 0)
%   'growthMode'    - 'none', 'grow', 'move', 'grow_and_move'
%                     Default: 'grow' if G.jtv exists, 'none' otherwise
%   'growthRate'    - Growth rate (nodes per time step or percentage per time step)
%                     Default: 1 node per time step
%   'moveSpeed'     - Movement speed (graph distance units per time step)
%                     Default: 1
%   'moveDirection' - Movement direction: 'random', 'radial_out', 'radial_in', or vector
%                     Default: 'random'
%   'seed'          - Random seed for reproducibility (default: current time)
%
% Outputs:
%   signal - Graph signal of size [G.N, 1] or [G.N, G.jtv.T] if temporal
%   params - Structure with generation parameters used
%
% Examples:
%   % Static patch (10% of nodes)
%   signal = generatePatchSignal(G);
%
%   % Growing patch over time
%   signal = generatePatchSignal(G, 'growthMode', 'grow', 'growthRate', 2);
%
%   % Moving patch without growth
%   signal = generatePatchSignal(G, 'growthMode', 'move', 'moveSpeed', 0.5);
%
%   % Large initial patch that grows and moves
%   signal = generatePatchSignal(G, 'patchSize', 0.2, 'growthMode', 'grow_and_move');

% Parse input parameters
p = inputParser;
addRequired(p, 'G');
addParameter(p, 'patchSize', 0.1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'patchCenter', 'auto');
addParameter(p, 'patchValue', 1, @isnumeric);
addParameter(p, 'backgroundValue', 0, @isnumeric);
addParameter(p, 'growthMode', [], @(x) ischar(x) || isstring(x));
addParameter(p, 'growthRate', 1, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'moveSpeed', 1, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'moveDirection', 'random');
addParameter(p, 'seed', [], @isnumeric);
parse(p, G, varargin{:});

% Set default growth mode based on whether temporal data exists
if isempty(p.Results.growthMode)
    if isfield(G, 'jtv') && isfield(G.jtv, 'T')
        growthMode = 'grow';
    else
        growthMode = 'none';
    end
else
    growthMode = p.Results.growthMode;
end

% Validate inputs
if ~isfield(G, 'N') || G.N < 1
    error('Graph G must have field N with number of vertices');
end

% Set random seed if provided
if ~isempty(p.Results.seed)
    rng(p.Results.seed);
end

% Determine time dimension
if isfield(G, 'jtv') && isfield(G.jtv, 'T')
    T = G.jtv.T;
    has_time = true;
else
    T = 1;
    has_time = false;
end

% Convert patch size to number of nodes
if p.Results.patchSize <= 1
    patch_size = max(1, round(p.Results.patchSize * G.N));
else
    patch_size = min(G.N, round(p.Results.patchSize));
end

% Determine patch center
center_node = determinePatchCenter(G, p.Results.patchCenter);

% Initialize signal
signal = ones(G.N, T) * p.Results.backgroundValue;

% Store parameters used
params = struct();
params.patchSize = patch_size;
params.patchCenter = center_node;
params.patchValue = p.Results.patchValue;
params.backgroundValue = p.Results.backgroundValue;
params.growthMode = growthMode;
params.growthRate = p.Results.growthRate;
params.moveSpeed = p.Results.moveSpeed;
params.moveDirection = p.Results.moveDirection;
params.hasTime = has_time;
params.T = T;

% Generate signal based on growth mode
switch lower(growthMode)
    case 'none'
        % Static patch
        patch_nodes = getPatchNodes(G, center_node, patch_size);
        signal(patch_nodes, :) = p.Results.patchValue;
        
    case 'grow'
        % Growing patch
        signal = generateGrowingPatch(G, signal, center_node, patch_size, ...
            p.Results.growthRate, p.Results.patchValue, T);
        
    case 'move'
        % Moving patch (no growth)
        signal = generateMovingPatch(G, signal, center_node, patch_size, ...
            p.Results.moveSpeed, p.Results.moveDirection, p.Results.patchValue, T);
        
    case 'grow_and_move'
        % Growing and moving patch
        signal = generateGrowingMovingPatch(G, signal, center_node, patch_size, ...
            p.Results.growthRate, p.Results.moveSpeed, p.Results.moveDirection, ...
            p.Results.patchValue, T);
        
    otherwise
        error('Unknown growth mode: %s', growthMode);
end

end

function center_node = determinePatchCenter(G, center_spec)
% Determine the center node for the patch

if isnumeric(center_spec)
    center_node = max(1, min(G.N, round(center_spec)));
elseif strcmpi(center_spec, 'random')
    center_node = randi(G.N);
elseif strcmpi(center_spec, 'auto')
    % Find node closest to graph center
    if isfield(G, 'coords') && ~isempty(G.coords)
        % Use geometric center
        center_pos = mean(G.coords, 1);
        distances = sqrt(sum((G.coords - center_pos).^2, 2));
        [~, center_node] = min(distances);
    else
        % Use graph-theoretic center (node with minimum maximum distance)
        center_node = findGraphCenter(G);
    end
else
    error('Invalid patchCenter specification: %s', center_spec);
end
end

function center_node = findGraphCenter(G)
% Find graph center using shortest path distances

if isfield(G, 'W') && ~isempty(G.W)
    % Use adjacency matrix if available
    W = G.W;
    % Convert to distance matrix (assume unit edge weights)
    D = 1 ./ (W + eye(size(W)));
    D(W == 0) = inf;
    D(eye(size(W)) == 1) = 0;
    
    % Floyd-Warshall for all shortest paths
    for k = 1:G.N
        for i = 1:G.N
            for j = 1:G.N
                if D(i,k) + D(k,j) < D(i,j)
                    D(i,j) = D(i,k) + D(k,j);
                end
            end
        end
    end
    
    % Find node with minimum eccentricity (maximum distance to other nodes)
    eccentricities = max(D, [], 2);
    [~, center_node] = min(eccentricities);
else
    % Fallback: use middle node
    center_node = round(G.N / 2);
end
end

function patch_nodes = getPatchNodes(G, center_node, patch_size)
% Get nodes in patch using graph distance from center

if patch_size >= G.N
    patch_nodes = 1:G.N;
    return;
end

if isfield(G, 'W') && ~isempty(G.W)
    % Use graph distances
    distances = computeGraphDistances(G, center_node);
    [~, sorted_idx] = sort(distances);
    patch_nodes = sorted_idx(1:patch_size);
else
    % Fallback: use spatial distances if coordinates available
    if isfield(G, 'coords') && ~isempty(G.coords)
        center_pos = G.coords(center_node, :);
        distances = sqrt(sum((G.coords - center_pos).^2, 2));
        [~, sorted_idx] = sort(distances);
        patch_nodes = sorted_idx(1:patch_size);
    else
        % Final fallback: use consecutive nodes
        half_size = floor(patch_size / 2);
        start_node = max(1, center_node - half_size);
        end_node = min(G.N, start_node + patch_size - 1);
        patch_nodes = start_node:end_node;
    end
end
end

function distances = computeGraphDistances(G, source_node)
% Compute shortest path distances from source node using Dijkstra's algorithm

distances = inf(G.N, 1);
distances(source_node) = 0;
visited = false(G.N, 1);

% Simple Dijkstra implementation
for i = 1:G.N
    % Find unvisited node with minimum distance
    unvisited_distances = distances;
    unvisited_distances(visited) = inf;
    [min_dist, current_node] = min(unvisited_distances);
    
    if isinf(min_dist)
        break; % No more reachable nodes
    end
    
    visited(current_node) = true;
    
    % Update distances to neighbors
    if isfield(G, 'W')
        neighbors = find(G.W(current_node, :) > 0);
        for neighbor = neighbors
            if ~visited(neighbor)
                edge_weight = G.W(current_node, neighbor);
                alt_distance = distances(current_node) + edge_weight;
                if alt_distance < distances(neighbor)
                    distances(neighbor) = alt_distance;
                end
            end
        end
    end
end
end

function signal = generateGrowingPatch(G, signal, center_node, initial_size, growth_rate, patch_value, T)
% Generate a growing patch over time

current_size = initial_size;
for t = 1:T
    % Get patch nodes for current size
    patch_nodes = getPatchNodes(G, center_node, round(current_size));
    signal(patch_nodes, t) = patch_value;
    
    % Increase size for next time step
    if t < T
        if growth_rate <= 1
            % Growth rate as percentage per time step
            current_size = min(G.N, current_size * (1 + growth_rate));
        else
            % Growth rate as nodes per time step
            current_size = min(G.N, current_size + growth_rate);
        end
    end
end
end

function signal = generateMovingPatch(G, signal, center_node, patch_size, move_speed, move_direction, patch_value, T)
% Generate a moving patch over time

current_center = center_node;
centers = zeros(T, 1);
centers(1) = current_center;

% Generate movement trajectory
for t = 2:T
    current_center = getNextCenter(G, current_center, move_speed, move_direction);
    centers(t) = current_center;
end

% Apply patch at each time step
for t = 1:T
    patch_nodes = getPatchNodes(G, centers(t), patch_size);
    signal(patch_nodes, t) = patch_value;
end
end

function signal = generateGrowingMovingPatch(G, signal, center_node, initial_size, growth_rate, move_speed, move_direction, patch_value, T)
% Generate a patch that both grows and moves over time

current_center = center_node;
current_size = initial_size;

for t = 1:T
    % Apply patch at current position and size
    patch_nodes = getPatchNodes(G, current_center, round(current_size));
    signal(patch_nodes, t) = patch_value;
    
    if t < T
        % Move center
        current_center = getNextCenter(G, current_center, move_speed, move_direction);
        
        % Grow size
        if growth_rate <= 1
            current_size = min(G.N, current_size * (1 + growth_rate));
        else
            current_size = min(G.N, current_size + growth_rate);
        end
    end
end
end

function next_center = getNextCenter(G, current_center, move_speed, move_direction)
% Get next center position based on movement parameters

if strcmpi(move_direction, 'random')
    % Random walk with speed consideration
    if isfield(G, 'W') && ~isempty(G.W)
        % Get neighbors within move_speed distance
        distances = computeGraphDistances(G, current_center);
        valid_nodes = find(distances <= move_speed & distances > 0);
        if ~isempty(valid_nodes)
            next_center = valid_nodes(randi(length(valid_nodes)));
        else
            next_center = current_center; % Stay if no reachable nodes
        end
    else
        % Fallback: random node selection
        next_center = randi(G.N);
    end
elseif strcmpi(move_direction, 'radial_out')
    % Move radially outward from graph center
    graph_center = findGraphCenter(G);
    if isfield(G, 'W') && ~isempty(G.W)
        distances_from_center = computeGraphDistances(G, graph_center);
        current_distance = distances_from_center(current_center);
        
        % Find nodes at greater distance from center
        target_distance = current_distance + move_speed;
        candidates = find(abs(distances_from_center - target_distance) <= 1);
        
        if ~isempty(candidates)
            next_center = candidates(randi(length(candidates)));
        else
            next_center = current_center;
        end
    else
        next_center = current_center;
    end
elseif strcmpi(move_direction, 'radial_in')
    % Move radially inward toward graph center
    graph_center = findGraphCenter(G);
    if isfield(G, 'W') && ~isempty(G.W)
        distances_from_center = computeGraphDistances(G, graph_center);
        current_distance = distances_from_center(current_center);
        
        % Find nodes at smaller distance from center
        target_distance = max(0, current_distance - move_speed);
        candidates = find(abs(distances_from_center - target_distance) <= 1);
        
        if ~isempty(candidates)
            next_center = candidates(randi(length(candidates)));
        else
            next_center = current_center;
        end
    else
        next_center = current_center;
    end
else
    % For custom direction vectors or other specifications
    next_center = current_center; % Stay in place for unsupported modes
end
end