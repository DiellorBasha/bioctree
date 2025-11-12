%% Simple BCT Creation Demo
% This script demonstrates how to create a BCT file with a simple graph
% and optional signal data in MATLAB

clear; close all; clc;

fprintf('=== Simple BCT Creation Demo ===\n\n');

%% 1. Define output file path
outfn = fullfile(fileparts(mfilename('fullpath')),'..','data','bioctree_files','raw','demo_simple.bct.h5');

% Ensure directory exists
if ~exist(fileparts(outfn), 'dir')
    mkdir(fileparts(outfn));
end

fprintf('Creating BCT file: %s\n', outfn);

%% 2. Create empty BCT instance
B = bct.bct.create(outfn);
fprintf('✓ Empty BCT file created\n');

%% 3. Create a simple graph - let's make a small 2D grid
fprintf('\n--- Creating Simple 2D Grid Graph ---\n');

% Grid parameters
grid_size = 5;  % 5x5 grid = 25 nodes
N = grid_size^2;

% Generate 2D grid coordinates
[X, Y] = meshgrid(1:grid_size, 1:grid_size);
coords = [X(:), Y(:), zeros(N, 1)];  % Z=0 for 2D grid

fprintf('Grid: %dx%d = %d vertices\n', grid_size, grid_size, N);

% Build edge connectivity for 4-connected grid
edges = [];
weights = [];

for i = 1:grid_size
    for j = 1:grid_size
        node_idx = (i-1)*grid_size + j;  % Current node index
        
        % Connect to right neighbor
        if j < grid_size
            right_idx = (i-1)*grid_size + (j+1);
            edges = [edges; node_idx, right_idx];
            weights = [weights; 1.0];  % Unit weight
        end
        
        % Connect to bottom neighbor  
        if i < grid_size
            bottom_idx = i*grid_size + j;
            edges = [edges; node_idx, bottom_idx];
            weights = [weights; 1.0];  % Unit weight
        end
    end
end

E = size(edges, 1);
fprintf('Generated %d edges (4-connected grid)\n', E);

%% 4. Create graph structure for BCT
G = struct();
G.coords = coords;                    % [N×3] vertex coordinates
G.E = [edges, weights];               % [E×3] edge list [i, j, weight]

% Optional: add graph metadata
G.type = 'grid_2d';
G.lap_type = 'combinatorial';

%% 5. Write graph to BCT file
fprintf('\n--- Writing Graph to BCT ---\n');
B.write_graph(G);
fprintf('✓ Graph written to BCT file\n');

%% 6. Create some simple signal data (optional)
fprintf('\n--- Adding Signal Data ---\n');

% Generate synthetic time series data
fs = 100;           % Sampling frequency (Hz)
duration = 2.0;     % Duration (seconds)
T = round(fs * duration);
t = (0:T-1) / fs;

% Create spatially varying sinusoidal signals
X = zeros(T, N);
for n = 1:N
    % Frequency varies with spatial position
    freq = 5 + 2 * coords(n, 1);  % 5-15 Hz based on X coordinate
    phase = 2*pi * coords(n, 2) / grid_size;  % Phase varies with Y
    
    X(:, n) = sin(2*pi*freq*t' + phase) + 0.1*randn(T, 1);
end

fprintf('Generated signal: %d samples × %d nodes (%.1fs at %.0f Hz)\n', T, N, duration, fs);

%% 7. Write signal data to BCT
B.write_raw(X, fs);
fprintf('✓ Signal data written to BCT file\n');

%% 8. Verify the created BCT file
fprintf('\n--- Verifying BCT File ---\n');

% Read back the graph
G_verify = B.read_graph_gsp();
coords_verify = B.read_coords();

fprintf('Verification:\n');
fprintf('  Nodes: %d (expected %d)\n', G_verify.N, N);
fprintf('  Edges: %d (expected %d)\n', nnz(G_verify.W)/2, E);
fprintf('  Coordinates shape: %dx%d\n', size(coords_verify));
fprintf('  Sampling rate: %.1f Hz\n', B.fs);
fprintf('  Signal duration: %.1f s\n', B.T / B.fs);

%% 9. Optional: Read back some signal data
X_verify = B.read_raw([1, min(100, T)], [1, N]);  % Read first 100 samples, all nodes
fprintf('  Signal verification: %dx%d samples read back\n', size(X_verify));

%% 10. Display file information
fprintf('\n--- File Information ---\n');
file_info = dir(outfn);
fprintf('File size: %.2f KB\n', file_info.bytes / 1024);

% Show HDF5 structure
fprintf('\nHDF5 Structure:\n');
try
    info = h5info(outfn);
    show_h5_structure(info, '');
catch ME
    fprintf('Could not read HDF5 structure: %s\n', ME.message);
end

fprintf('\n=== Demo Complete ===\n');
fprintf('You can now:\n');
fprintf('  1. Load this file: B = bct.bct.open(''%s'')\n', outfn);
fprintf('  2. Read graph: G = B.read_graph_gsp()\n');
fprintf('  3. Read signals: X = B.read_raw([1, 100], [1, 25])\n');
fprintf('  4. Visualize: plot_graph_signal(G, X(:,1))\n');

%% Helper function to display HDF5 structure
function show_h5_structure(info, indent)
    % Display groups
    for i = 1:length(info.Groups)
        fprintf('%s/%s/\n', indent, info.Groups(i).Name);
        show_h5_structure(info.Groups(i), [indent, '  ']);
    end
    
    % Display datasets
    for i = 1:length(info.Datasets)
        ds = info.Datasets(i);
        shape_str = sprintf('%dx', ds.Dataspace.Size);
        shape_str = shape_str(1:end-1); % Remove trailing 'x'
        fprintf('%s  %s [%s %s]\n', indent, ds.Name, shape_str, ds.Datatype.Class);
    end
end

%% Bonus: Simple visualization function
function plot_graph_signal(G, signal)
    figure('Name', 'Simple Graph Signal Visualization');
    
    % Plot graph structure
    subplot(1, 2, 1);
    gsp_plot_graph(G);
    title('Graph Structure');
    axis equal;
    
    % Plot signal on graph
    subplot(1, 2, 2);
    G.plotting.vertex_color = signal;
    gsp_plot_signal(G, signal);
    title('Signal on Graph');
    colorbar;
    axis equal;
end