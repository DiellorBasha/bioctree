%% Minimal BCT Creation Example
% Simple example showing the essential steps to create a BCT file

clear; clc;

%% 1. Create BCT file
outfn = 'simple_graph.bct.h5';
B = bct.bct.create(outfn);
fprintf('✓ Created BCT file: %s\n', outfn);

%% 2. Define a simple triangle graph
% Three nodes in a triangle
coords = [0, 0, 0;     % Node 1
          1, 0, 0;     % Node 2  
          0.5, 1, 0];  % Node 3

% Three edges connecting them
edges = [1, 2;         % Node 1 -> Node 2
         2, 3;         % Node 2 -> Node 3
         3, 1];        % Node 3 -> Node 1
         
weights = [1; 1; 1];   % Unit weights

%% 3. Create graph structure
G = struct();
G.coords = coords;                    % Vertex positions
G.E = [edges, weights];               % Edge list with weights

%% 4. Write to BCT
B.write_graph(G);
fprintf('✓ Graph written: 3 nodes, 3 edges\n');

%% 5. Optional: Add signal data
fs = 100;                            % Sampling rate
T = 200;                             % 200 time points (2 seconds)
X = randn(T, 3);                     % Random signals for 3 nodes

B.write_raw(X, fs);
fprintf('✓ Signal written: %d samples, 3 nodes\n', T);

%% 6. Verify
G_read = B.read_graph_gsp();
fprintf('✓ Verification: %d nodes, %d edges\n', G_read.N, nnz(G_read.W)/2);

% Clean up
clear B;  % Close file handle