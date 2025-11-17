function [signal, params] = patch_signal(B, varargin)
%PATCH_SIGNAL Generate a patch signal on a graph with optional temporal dynamics
%
%   signal = bct.sim.patch_signal(B) generates a static patch signal (10% of nodes)
%
%   signal = bct.sim.patch_signal(B, Name, Value) specifies options:
%
%   Parameters:
%       'patchSize'     - Initial patch size as percentage (0-1) or number of nodes
%                         Default: 0.1 (10% of nodes)
%       'patchCenter'   - Center node index or 'random' or 'auto'
%                         Default: 'auto' (node closest to coordinate centroid)
%       'patchValue'    - Value inside the patch (default: 1)
%       'backgroundValue' - Value outside the patch (default: 0)
%       'T'             - Number of time points (default: 1, static)
%       'growthMode'    - 'none', 'grow', 'move', 'grow_and_move'
%                         Default: 'none'
%       'growthRate'    - Growth rate (nodes per time step or percentage)
%                         Default: 1 node per time step
%       'moveSpeed'     - Movement speed (graph distance units per time)
%                         Default: 1
%       'moveDirection' - 'random', 'radial_out', 'radial_in'
%                         Default: 'random'
%       'seed'          - Random seed for reproducibility (default: [])
%
%   Returns:
%       signal - N×1 or N×T single precision graph signal
%       params - Structure with generation parameters used
%
%   Examples:
%       B = bct.io.graph.Import.fromFreeSurfer('lh.pial');
%       
%       % Static patch (10% of nodes)
%       signal = bct.sim.patch_signal(B);
%       
%       % Growing patch over time
%       signal = bct.sim.patch_signal(B, 'T', 100, 'growthMode', 'grow');
%       
%       % Moving patch
%       signal = bct.sim.patch_signal(B, 'T', 50, 'growthMode', 'move');
%
%   See also: bct.sim.gaussian, bct.sim.gaussian_growth

    % Get dimensions from Manifold
    N = size(B.Manifold.V, 1);
    
    % Parse input parameters
    p = inputParser;
    p.addParameter('patchSize', 0.1, @(x) isnumeric(x) && x > 0);
    p.addParameter('patchCenter', 'auto');
    p.addParameter('patchValue', 1, @isnumeric);
    p.addParameter('backgroundValue', 0, @isnumeric);
    p.addParameter('T', 1, @(x) isnumeric(x) && x >= 1);
    p.addParameter('growthMode', 'none', @(x) ischar(x) || isstring(x));
    p.addParameter('growthRate', 1, @(x) isnumeric(x) && x >= 0);
    p.addParameter('moveSpeed', 1, @(x) isnumeric(x) && x >= 0);
    p.addParameter('moveDirection', 'random');
    p.addParameter('seed', [], @isnumeric);
    p.parse(varargin{:});
    
    T = round(p.Results.T);
    
    % Set random seed if provided
    if ~isempty(p.Results.seed)
        rng(p.Results.seed);
    end
    
    % Convert patch size to number of nodes
    if p.Results.patchSize <= 1
        patch_size = max(1, round(p.Results.patchSize * N));
    else
        patch_size = min(N, round(p.Results.patchSize));
    end
    
    % Determine patch center
    center_node = determinePatchCenter(B, p.Results.patchCenter);
    
    % Initialize signal
    signal = ones(N, T, 'single') * p.Results.backgroundValue;
    
    % Store parameters
    params = struct();
    params.patchSize = patch_size;
    params.patchCenter = center_node;
    params.patchValue = p.Results.patchValue;
    params.backgroundValue = p.Results.backgroundValue;
    params.growthMode = p.Results.growthMode;
    params.growthRate = p.Results.growthRate;
    params.moveSpeed = p.Results.moveSpeed;
    params.moveDirection = p.Results.moveDirection;
    params.T = T;
    
    % Generate signal based on growth mode
    growthMode = lower(string(p.Results.growthMode));
    
    switch growthMode
        case 'none'
            % Static patch
            patch_nodes = getPatchNodes(B, center_node, patch_size);
            signal(patch_nodes, :) = p.Results.patchValue;
            
        case 'grow'
            % Growing patch
            signal = generateGrowingPatch(B, signal, center_node, patch_size, ...
                p.Results.growthRate, p.Results.patchValue, T);
            
        case 'move'
            % Moving patch (no growth)
            signal = generateMovingPatch(B, signal, center_node, patch_size, ...
                p.Results.moveSpeed, p.Results.moveDirection, p.Results.patchValue, T);
            
        case 'grow_and_move'
            % Growing and moving patch
            signal = generateGrowingMovingPatch(B, signal, center_node, patch_size, ...
                p.Results.growthRate, p.Results.moveSpeed, p.Results.moveDirection, ...
                p.Results.patchValue, T);
            
        otherwise
            error('bct:sim:patch_signal:unknownGrowthMode', ...
                'Unknown growth mode: %s', growthMode);
    end
end

%% Helper functions

function center_node = determinePatchCenter(B, center_spec)
    % Determine the center node for the patch
    N = size(B.Manifold.V, 1);
    coords = B.Manifold.V;
    
    if isnumeric(center_spec)
        center_node = max(1, min(N, round(center_spec)));
    elseif strcmpi(center_spec, 'random')
        center_node = randi(N);
    elseif strcmpi(center_spec, 'auto')
        % Find node closest to coordinate centroid
        if ~isempty(coords)
            center_pos = mean(double(coords), 1);
            distances = vecnorm(double(coords) - center_pos, 2, 2);
            [~, center_node] = min(distances);
        else
            % Fallback: use graph-theoretic center
            center_node = findGraphCenter(B);
        end
    else
        error('bct:sim:patch_signal:invalidCenter', ...
            'Invalid patchCenter: %s', center_spec);
    end
end

function center_node = findGraphCenter(B)
    % Find graph center using geodesic distances
    A = B.Manifold.adjacency();
    if ~isequal(A, A')
        A = max(A, A');
    end
    
    Gm = graph(A, 'OmitSelfLoops');
    N = size(B.Manifold.V, 1);
    
    % Compute eccentricity for each node
    eccentricities = zeros(N, 1);
    for i = 1:N
        d = distances(Gm, i, 'Method', 'positive');
        d(~isfinite(d)) = 0;
        eccentricities(i) = max(d);
    end
    
    % Node with minimum eccentricity is the center
    [~, center_node] = min(eccentricities);
end

function patch_nodes = getPatchNodes(B, center_node, patch_size)
    % Get nodes in patch using graph distance from center
    N = size(B.Manifold.V, 1);
    
    if patch_size >= N
        patch_nodes = 1:N;
        return;
    end
    
    % Use geodesic distances
    A = B.Manifold.adjacency();
    if ~isequal(A, A')
        A = max(A, A');
    end
    Gm = graph(A, 'OmitSelfLoops');
    
    distances_vec = distances(Gm, center_node, 'Method', 'positive');
    distances_vec = full(distances_vec(:));
    distances_vec(~isfinite(distances_vec)) = inf;
    
    [~, sorted_idx] = sort(distances_vec);
    patch_nodes = sorted_idx(1:patch_size);
end

function signal = generateGrowingPatch(B, signal, center_node, initial_size, growth_rate, patch_value, T)
    % Generate a growing patch over time
    N = size(B.Manifold.V, 1);
    current_size = initial_size;
    
    for t = 1:T
        % Get patch nodes for current size
        patch_nodes = getPatchNodes(B, center_node, round(current_size));
        signal(patch_nodes, t) = patch_value;
        
        % Increase size for next time step
        if t < T
            if growth_rate <= 1
                % Growth rate as percentage per time step
                current_size = min(N, current_size * (1 + growth_rate));
            else
                % Growth rate as nodes per time step
                current_size = min(N, current_size + growth_rate);
            end
        end
    end
end

function signal = generateMovingPatch(B, signal, center_node, patch_size, move_speed, move_direction, patch_value, T)
    % Generate a moving patch over time
    current_center = center_node;
    centers = zeros(T, 1);
    centers(1) = current_center;
    
    % Generate movement trajectory
    for t = 2:T
        current_center = getNextCenter(B, current_center, move_speed, move_direction);
        centers(t) = current_center;
    end
    
    % Apply patch at each time step
    for t = 1:T
        patch_nodes = getPatchNodes(B, centers(t), patch_size);
        signal(patch_nodes, t) = patch_value;
    end
end

function signal = generateGrowingMovingPatch(B, signal, center_node, initial_size, growth_rate, move_speed, move_direction, patch_value, T)
    % Generate a patch that both grows and moves over time
    N = size(B.Manifold.V, 1);
    current_center = center_node;
    current_size = initial_size;
    
    for t = 1:T
        % Apply patch at current position and size
        patch_nodes = getPatchNodes(B, current_center, round(current_size));
        signal(patch_nodes, t) = patch_value;
        
        if t < T
            % Move center
            current_center = getNextCenter(B, current_center, move_speed, move_direction);
            
            % Grow size
            if growth_rate <= 1
                current_size = min(N, current_size * (1 + growth_rate));
            else
                current_size = min(N, current_size + growth_rate);
            end
        end
    end
end

function next_center = getNextCenter(B, current_center, move_speed, move_direction)
    % Get next center position based on movement parameters
    N = size(B.Manifold.V, 1);
    A = B.Manifold.adjacency();
    if ~isequal(A, A')
        A = max(A, A');
    end
    Gm = graph(A, 'OmitSelfLoops');
    
    if strcmpi(move_direction, 'random')
        % Random walk with speed consideration
        distances_vec = distances(Gm, current_center, 'Method', 'positive');
        distances_vec = full(distances_vec(:));
        distances_vec(~isfinite(distances_vec)) = inf;
        
        valid_nodes = find(distances_vec <= move_speed & distances_vec > 0);
        if ~isempty(valid_nodes)
            next_center = valid_nodes(randi(length(valid_nodes)));
        else
            next_center = current_center; % Stay if no reachable nodes
        end
        
    elseif strcmpi(move_direction, 'radial_out')
        % Move radially outward from graph center
        graph_center = findGraphCenter(B);
        distances_from_center = distances(Gm, graph_center, 'Method', 'positive');
        distances_from_center = full(distances_from_center(:));
        distances_from_center(~isfinite(distances_from_center)) = inf;
        
        current_distance = distances_from_center(current_center);
        target_distance = current_distance + move_speed;
        candidates = find(abs(distances_from_center - target_distance) <= 1);
        
        if ~isempty(candidates)
            next_center = candidates(randi(length(candidates)));
        else
            next_center = current_center;
        end
        
    elseif strcmpi(move_direction, 'radial_in')
        % Move radially inward toward graph center
        graph_center = findGraphCenter(B);
        distances_from_center = distances(Gm, graph_center, 'Method', 'positive');
        distances_from_center = full(distances_from_center(:));
        distances_from_center(~isfinite(distances_from_center)) = inf;
        
        current_distance = distances_from_center(current_center);
        target_distance = max(0, current_distance - move_speed);
        candidates = find(abs(distances_from_center - target_distance) <= 1);
        
        if ~isempty(candidates)
            next_center = candidates(randi(length(candidates)));
        else
            next_center = current_center;
        end
    else
        % Unsupported mode
        next_center = current_center;
    end
end
