function [signal, params] = generateSpatioTemporalPattern(G, pattern_type, varargin)
% GENERATESPATIOTEMPORALPATTERN Generate various spatiotemporal patterns on graphs
%
% Usage:
%   [signal, params] = generateSpatioTemporalPattern(G, pattern_type)
%   [signal, params] = generateSpatioTemporalPattern(G, pattern_type, 'param', value, ...)
%
% Inputs:
%   G - Graph structure with at least G.N (number of vertices)
%       Optional: G.jtv with G.jtv.T (time steps) and G.jtv.fs (sampling frequency)
%   pattern_type - String specifying pattern type:
%       'patch' - Patch signal (uses generatePatchSignal)
%       'wave' - Traveling wave
%       'ripple' - Ripple pattern (expanding circular wave)
%       'oscillation' - Localized oscillation
%       'burst' - Brief burst of activity
%       'gradient' - Spatial gradient pattern
%       'noise' - Structured noise pattern
%
% Parameters (pattern-specific):
%   General:
%   'amplitude'     - Signal amplitude (default: 1)
%   'seed'          - Random seed (default: current time)
%
%   Wave-specific:
%   'waveSpeed'     - Wave propagation speed (default: 1)
%   'waveDirection' - Wave direction (default: 'random')
%   'frequency'     - Temporal frequency for oscillatory patterns (default: 1 Hz)
%
%   Noise-specific:
%   'noiseType'     - 'white', 'colored', 'structured' (default: 'white')
%   'correlation'   - Spatial correlation parameter (default: 0.1)
%
% Outputs:
%   signal - Graph signal of size [G.N, 1] or [G.N, G.jtv.T] if temporal
%   params - Structure with generation parameters used
%
% Examples:
%   % Generate traveling wave
%   signal = generateSpatioTemporalPattern(G, 'wave', 'waveSpeed', 2);
%
%   % Generate ripple pattern
%   signal = generateSpatioTemporalPattern(G, 'ripple', 'amplitude', 0.5);
%
%   % Generate oscillating burst
%   signal = generateSpatioTemporalPattern(G, 'oscillation', 'frequency', 2);

% Parse inputs
p = inputParser;
addRequired(p, 'G');
addRequired(p, 'pattern_type', @(x) ischar(x) || isstring(x));
addParameter(p, 'amplitude', 1, @isnumeric);
addParameter(p, 'seed', [], @isnumeric);
addParameter(p, 'waveSpeed', 1, @isnumeric);
addParameter(p, 'waveDirection', 'random');
addParameter(p, 'frequency', 1, @isnumeric);
addParameter(p, 'noiseType', 'white', @(x) ischar(x) || isstring(x));
addParameter(p, 'correlation', 0.1, @isnumeric);
parse(p, G, pattern_type, varargin{:});

% Set random seed if provided
if ~isempty(p.Results.seed)
    rng(p.Results.seed);
end

% Determine time dimension
if isfield(G, 'jtv') && isfield(G.jtv, 'T')
    T = G.jtv.T;
    fs = G.jtv.fs;
    has_time = true;
else
    T = 1;
    fs = 1;
    has_time = false;
end

% Generate pattern based on type
switch lower(pattern_type)
    case 'patch'
        % Delegate to generatePatchSignal
        [signal, params] = generatePatchSignal(G, varargin{:});
        
    case 'wave'
        [signal, params] = generateTravelingWave(G, T, fs, p.Results);
        
    case 'ripple'
        [signal, params] = generateRipplePattern(G, T, fs, p.Results);
        
    case 'oscillation'
        [signal, params] = generateOscillation(G, T, fs, p.Results);
        
    case 'burst'
        [signal, params] = generateBurst(G, T, fs, p.Results);
        
    case 'gradient'
        [signal, params] = generateGradientPattern(G, T, fs, p.Results);
        
    case 'noise'
        [signal, params] = generateNoisePattern(G, T, fs, p.Results);
        
    otherwise
        error('Unknown pattern type: %s', pattern_type);
end

% Apply amplitude scaling
signal = signal * p.Results.amplitude;
params.amplitude = p.Results.amplitude;
params.pattern_type = pattern_type;
params.hasTime = has_time;
params.T = T;
if has_time
    params.fs = fs;
end

end

function [signal, params] = generateTravelingWave(G, T, fs, opts)
% Generate a traveling wave pattern

% Initialize signal
signal = zeros(G.N, T);
params = struct();

% Determine wave source and direction
source_node = randi(G.N);
params.source_node = source_node;
params.waveSpeed = opts.waveSpeed;
params.waveDirection = opts.waveDirection;

if T == 1
    % Static wave snapshot
    if isfield(G, 'coords') && ~isempty(G.coords)
        % Use spatial coordinates
        center_pos = G.coords(source_node, :);
        distances = sqrt(sum((G.coords - center_pos).^2, 2));
    else
        % Use graph distances
        distances = computeGraphDistances(G, source_node);
    end
    
    % Create wave pattern
    wave_frequency = 0.1; % Spatial frequency
    signal(:, 1) = sin(wave_frequency * distances);
else
    % Time-varying wave
    for t = 1:T
        time = (t-1) / fs;
        
        % Compute wave front position
        if isfield(G, 'coords') && ~isempty(G.coords)
            center_pos = G.coords(source_node, :);
            distances = sqrt(sum((G.coords - center_pos).^2, 2));
        else
            distances = computeGraphDistances(G, source_node);
        end
        
        % Wave equation: sin(kx - wt)
        wave_number = 0.1;
        angular_freq = 2 * pi * opts.frequency;
        signal(:, t) = sin(wave_number * distances - angular_freq * time);
        
        % Apply wave speed by shifting the pattern
        wave_front = opts.waveSpeed * time;
        signal(:, t) = signal(:, t) .* (distances <= wave_front);
    end
end

params.frequency = opts.frequency;
end

function [signal, params] = generateRipplePattern(G, T, fs, opts)
% Generate expanding ripple pattern

signal = zeros(G.N, T);
params = struct();

% Choose center for ripple
center_node = randi(G.N);
params.center_node = center_node;
params.waveSpeed = opts.waveSpeed;

% Compute distances from center
if isfield(G, 'coords') && ~isempty(G.coords)
    center_pos = G.coords(center_node, :);
    distances = sqrt(sum((G.coords - center_pos).^2, 2));
else
    distances = computeGraphDistances(G, center_node);
end

if T == 1
    % Static ripple
    ripple_freq = 0.2;
    signal(:, 1) = sin(ripple_freq * distances) .* exp(-0.1 * distances);
else
    % Expanding ripple
    for t = 1:T
        time = (t-1) / fs;
        
        % Ripple equation with expansion
        ripple_radius = opts.waveSpeed * time;
        ripple_width = 2; % Width of the ripple
        
        % Create expanding ring
        ring_distance = abs(distances - ripple_radius);
        amplitude = exp(-ring_distance / ripple_width);
        
        % Add oscillation
        phase = 2 * pi * opts.frequency * time;
        signal(:, t) = amplitude .* sin(phase);
    end
end

params.frequency = opts.frequency;
end

function [signal, params] = generateOscillation(G, T, fs, opts)
% Generate localized oscillation

signal = zeros(G.N, T);
params = struct();

% Choose oscillation center and extent
center_node = randi(G.N);
oscillation_size = max(1, round(0.1 * G.N)); % 10% of nodes

params.center_node = center_node;
params.oscillation_size = oscillation_size;
params.frequency = opts.frequency;

% Get nodes in oscillation region
patch_nodes = getPatchNodes(G, center_node, oscillation_size);

if T == 1
    % Static oscillation (just the spatial extent)
    signal(patch_nodes, 1) = 1;
else
    % Time-varying oscillation
    for t = 1:T
        time = (t-1) / fs;
        amplitude = sin(2 * pi * opts.frequency * time);
        signal(patch_nodes, t) = amplitude;
    end
end
end

function [signal, params] = generateBurst(G, T, fs, opts)
% Generate brief burst of activity

signal = zeros(G.N, T);
params = struct();

% Choose burst parameters
center_node = randi(G.N);
burst_size = max(1, round(0.05 * G.N)); % 5% of nodes
burst_nodes = getPatchNodes(G, center_node, burst_size);

params.center_node = center_node;
params.burst_size = burst_size;

if T == 1
    % Static burst
    signal(burst_nodes, 1) = 1;
else
    % Temporal burst (Gaussian envelope)
    burst_duration = min(T, round(T/4)); % Quarter of total time
    burst_start = randi(max(1, T - burst_duration));
    
    for t = 1:T
        if t >= burst_start && t <= burst_start + burst_duration
            % Gaussian envelope
            t_rel = (t - burst_start) / burst_duration;
            envelope = exp(-((t_rel - 0.5) / 0.2)^2);
            
            % Optional oscillation within burst
            oscillation = sin(2 * pi * opts.frequency * (t-1) / fs);
            signal(burst_nodes, t) = envelope * oscillation;
        end
    end
    
    params.burst_start = burst_start;
    params.burst_duration = burst_duration;
end
end

function [signal, params] = generateGradientPattern(G, T, fs, opts)
% Generate spatial gradient pattern

signal = zeros(G.N, T);
params = struct();

if isfield(G, 'coords') && size(G.coords, 2) >= 2
    % Use coordinates to create gradient
    coords = G.coords;
    
    % Random gradient direction
    gradient_dir = randn(1, size(coords, 2));
    gradient_dir = gradient_dir / norm(gradient_dir);
    
    % Project coordinates onto gradient direction
    projection = coords * gradient_dir';
    
    % Normalize to [0, 1]
    projection = (projection - min(projection)) / (max(projection) - min(projection));
    
    params.gradient_direction = gradient_dir;
else
    % Use node indices as proxy for spatial arrangement
    projection = (1:G.N)' / G.N;
    params.gradient_direction = 'node_index';
end

if T == 1
    % Static gradient
    signal(:, 1) = projection;
else
    % Time-varying gradient (rotating or shifting)
    for t = 1:T
        time = (t-1) / fs;
        
        % Add temporal modulation
        phase = 2 * pi * opts.frequency * time;
        signal(:, t) = projection .* (0.5 + 0.5 * sin(phase));
    end
end

params.frequency = opts.frequency;
end

function [signal, params] = generateNoisePattern(G, T, ~, opts)
% Generate structured noise pattern

signal = zeros(G.N, T);
params = struct();

params.noiseType = opts.noiseType;
params.correlation = opts.correlation;

switch lower(opts.noiseType)
    case 'white'
        % White noise (independent at each node and time)
        signal = randn(G.N, T);
        
    case 'colored'
        % Spatially correlated noise
        if isfield(G, 'W') && ~isempty(G.W)
            % Use graph structure for correlation
            base_noise = randn(G.N, T);
            
            % Apply spatial smoothing based on graph adjacency
            for t = 1:T
                for iter = 1:3 % Multiple smoothing iterations
                    smooth_signal = zeros(G.N, 1);
                    for i = 1:G.N
                        neighbors = find(G.W(i, :) > 0);
                        if ~isempty(neighbors)
                            smooth_signal(i) = (1-opts.correlation) * base_noise(i, t) + ...
                                             opts.correlation * mean(base_noise(neighbors, t));
                        else
                            smooth_signal(i) = base_noise(i, t);
                        end
                    end
                    base_noise(:, t) = smooth_signal;
                end
                signal(:, t) = base_noise(:, t);
            end
        else
            % Fallback to white noise
            signal = randn(G.N, T);
        end
        
    case 'structured'
        % Noise with temporal and spatial structure
        base_signal = randn(G.N, T);
        
        % Apply temporal smoothing
        if T > 1
            for i = 1:G.N
                signal(i, :) = smooth(base_signal(i, :), max(3, round(T/10)));
            end
        else
            signal = base_signal;
        end
        
        % Apply spatial correlation as above
        if isfield(G, 'W') && ~isempty(G.W) && T > 1
            for t = 1:T
                smooth_signal = zeros(G.N, 1);
                for i = 1:G.N
                    neighbors = find(G.W(i, :) > 0);
                    if ~isempty(neighbors)
                        smooth_signal(i) = (1-opts.correlation) * signal(i, t) + ...
                                         opts.correlation * mean(signal(neighbors, t));
                    else
                        smooth_signal(i) = signal(i, t);
                    end
                end
                signal(:, t) = smooth_signal;
            end
        end
end
end

% Helper function to get patch nodes (copied from generatePatchSignal for independence)
function patch_nodes = getPatchNodes(G, center_node, patch_size)
if patch_size >= G.N
    patch_nodes = 1:G.N;
    return;
end

if isfield(G, 'W') && ~isempty(G.W)
    distances = computeGraphDistances(G, center_node);
    [~, sorted_idx] = sort(distances);
    patch_nodes = sorted_idx(1:patch_size);
else
    if isfield(G, 'coords') && ~isempty(G.coords)
        center_pos = G.coords(center_node, :);
        distances = sqrt(sum((G.coords - center_pos).^2, 2));
        [~, sorted_idx] = sort(distances);
        patch_nodes = sorted_idx(1:patch_size);
    else
        half_size = floor(patch_size / 2);
        start_node = max(1, center_node - half_size);
        end_node = min(G.N, start_node + patch_size - 1);
        patch_nodes = start_node:end_node;
    end
end
end

% Helper function for graph distances (copied for independence)
function distances = computeGraphDistances(G, source_node)
distances = inf(G.N, 1);
distances(source_node) = 0;
visited = false(G.N, 1);

for i = 1:G.N
    unvisited_distances = distances;
    unvisited_distances(visited) = inf;
    [min_dist, current_node] = min(unvisited_distances);
    
    if isinf(min_dist)
        break;
    end
    
    visited(current_node) = true;
    
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