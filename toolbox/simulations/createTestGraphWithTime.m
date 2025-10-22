function G = createTestGraphWithTime(graph_type, varargin)
% CREATETESTGRAPHWITHTIME Create test graphs with temporal structure for pattern generation
%
% Usage:
%   G = createTestGraphWithTime(graph_type)
%   G = createTestGraphWithTime(graph_type, 'param', value, ...)
%
% Inputs:
%   graph_type - String specifying graph type:
%       'grid2d' - 2D grid graph
%       'grid3d' - 3D grid graph  
%       'sphere' - Spherical mesh (icosphere)
%       'brain'  - Brain-like surface (if available)
%       'random' - Random geometric graph
%       'lattice' - Regular lattice
%       'swiss_roll' - Swiss roll manifold
%
% Parameters:
%   'N'         - Number of vertices (approximate for some graphs)
%   'T'         - Number of time steps (default: 50)
%   'fs'        - Sampling frequency in Hz (default: 10)
%   'coords'    - Whether to include spatial coordinates (default: true)
%   'seed'      - Random seed for reproducibility
%
% Output:
%   G - Graph structure with fields:
%       G.N     - Number of vertices
%       G.W     - Adjacency matrix (sparse)
%       G.coords - Vertex coordinates [N x 2] or [N x 3]
%       G.jtv   - Temporal structure with G.jtv.T and G.jtv.fs
%
% Examples:
%   % Create 2D grid with temporal structure
%   G = createTestGraphWithTime('grid2d', 'N', 100, 'T', 100, 'fs', 20);
%
%   % Create sphere mesh for brain-like patterns
%   G = createTestGraphWithTime('sphere', 'N', 500, 'T', 200);
%
%   % Create random graph for testing
%   G = createTestGraphWithTime('random', 'N', 200, 'T', 50);

% Parse inputs
p = inputParser;
addRequired(p, 'graph_type', @(x) ischar(x) || isstring(x));
addParameter(p, 'N', 100, @(x) isnumeric(x) && x > 0);
addParameter(p, 'T', 50, @(x) isnumeric(x) && x > 0);
addParameter(p, 'fs', 10, @(x) isnumeric(x) && x > 0);
addParameter(p, 'coords', true, @islogical);
addParameter(p, 'seed', [], @isnumeric);
parse(p, graph_type, varargin{:});

% Set random seed if provided
if ~isempty(p.Results.seed)
    rng(p.Results.seed);
end

% Create graph based on type
switch lower(graph_type)
    case 'grid2d'
        G = createGrid2D(p.Results.N, p.Results.coords);
    case 'grid3d'
        G = createGrid3D(p.Results.N, p.Results.coords);
    case 'sphere'
        G = createSphere(p.Results.N, p.Results.coords);
    case 'brain'
        G = createBrainLike(p.Results.N, p.Results.coords);
    case 'random'
        G = createRandomGeometric(p.Results.N, p.Results.coords);
    case 'lattice'
        G = createLattice(p.Results.N, p.Results.coords);
    case 'swiss_roll'
        G = createSwissRoll(p.Results.N, p.Results.coords);
    otherwise
        error('Unknown graph type: %s', graph_type);
end

% Add temporal structure
G.jtv = struct();
G.jtv.T = p.Results.T;
G.jtv.fs = p.Results.fs;
G.jtv.dt = 1 / p.Results.fs;

fprintf('Created %s graph: %d vertices, %d edges, %d time steps (%.1f Hz)\n', ...
        graph_type, G.N, nnz(G.W)/2, G.jtv.T, G.jtv.fs);
end

function G = createGrid2D(N, include_coords)
% Create 2D grid graph using GSPBox if available, otherwise custom implementation

% Try to use GSPBox gsp_2dgrid function first
if exist('gsp_2dgrid', 'file')
    try
        % Determine grid dimensions
        side_length = round(sqrt(N));
        
        % Create graph with GSPBox (keeps default GSPBox size)
        G_gsp = gsp_2dgrid(side_length);
        
        % Convert to our format
        G = struct();
        G.N = G_gsp.N;
        G.W = G_gsp.W;
        if include_coords && isfield(G_gsp, 'coords')
            G.coords = G_gsp.coords;
        elseif include_coords
            % Generate coordinates if GSPBox doesn't provide them
            [X, Y] = meshgrid(1:side_length, 1:side_length);
            G.coords = [X(:), Y(:)];
        end
        return;
    catch ME
        warning('GSPBox:Fallback', 'GSPBox gsp_2dgrid failed: %s. Using fallback implementation.', ME.message);
    end
end

% Fallback: Custom implementation
% Determine grid dimensions
side_length = round(sqrt(N));
actual_N = side_length^2;

% Create coordinates
if include_coords
    [X, Y] = meshgrid(1:side_length, 1:side_length);
    coords = [X(:), Y(:)];
else
    coords = [];
end

% Create adjacency matrix
W = sparse(actual_N, actual_N);

for i = 1:side_length
    for j = 1:side_length
        node_idx = (i-1)*side_length + j;
        
        % Connect to right neighbor
        if j < side_length
            right_neighbor = (i-1)*side_length + j + 1;
            W(node_idx, right_neighbor) = 1;
            W(right_neighbor, node_idx) = 1;
        end
        
        % Connect to bottom neighbor
        if i < side_length
            bottom_neighbor = i*side_length + j;
            W(node_idx, bottom_neighbor) = 1;
            W(bottom_neighbor, node_idx) = 1;
        end
    end
end

G = struct();
G.N = actual_N;
G.W = W;
if include_coords
    G.coords = coords;
end
end

function G = createGrid3D(N, include_coords)
% Create 3D grid graph

% Determine grid dimensions
side_length = round(N^(1/3));
actual_N = side_length^3;

% Create coordinates
if include_coords
    [X, Y, Z] = meshgrid(1:side_length, 1:side_length, 1:side_length);
    coords = [X(:), Y(:), Z(:)];
else
    coords = [];
end

% Create adjacency matrix
W = sparse(actual_N, actual_N);

for i = 1:side_length
    for j = 1:side_length
        for k = 1:side_length
            node_idx = (i-1)*side_length^2 + (j-1)*side_length + k;
            
            % Connect to 6 neighbors in 3D grid
            neighbors = [];
            
            % X direction
            if i < side_length
                neighbors(end+1) = i*side_length^2 + (j-1)*side_length + k;
            end
            
            % Y direction  
            if j < side_length
                neighbors(end+1) = (i-1)*side_length^2 + j*side_length + k;
            end
            
            % Z direction
            if k < side_length
                neighbors(end+1) = (i-1)*side_length^2 + (j-1)*side_length + k + 1;
            end
            
            for neighbor = neighbors
                W(node_idx, neighbor) = 1;
                W(neighbor, node_idx) = 1;
            end
        end
    end
end

G = struct();
G.N = actual_N;
G.W = W;
if include_coords
    G.coords = coords;
end
end

function G = createSphere(N, include_coords)
% Create spherical mesh using GSPBox if available, otherwise custom implementation

% Try to use GSPBox gsp_sphere function first
if exist('gsp_sphere', 'file')
    try
        % Create graph with GSPBox (keeps default GSPBox size)
        G_gsp = gsp_sphere();
        
        % Convert to our format
        G = struct();
        G.N = G_gsp.N;
        G.W = G_gsp.W;
        if include_coords && isfield(G_gsp, 'coords')
            G.coords = G_gsp.coords;
        end
        return;
    catch ME
        warning('GSPBox:Fallback', 'GSPBox gsp_sphere failed: %s. Using fallback implementation.', ME.message);
    end
end

% Fallback: Custom implementation using subdivision
% Start with icosahedron and subdivide
if N < 100
    subdivisions = 1;
elseif N < 500
    subdivisions = 2;
else
    subdivisions = 3;
end

% Basic icosahedron vertices
phi = (1 + sqrt(5)) / 2; % Golden ratio
vertices = [
    [-1,  phi,  0];
    [ 1,  phi,  0];
    [-1, -phi,  0];
    [ 1, -phi,  0];
    [ 0, -1,  phi];
    [ 0,  1,  phi];
    [ 0, -1, -phi];
    [ 0,  1, -phi];
    [ phi,  0, -1];
    [ phi,  0,  1];
    [-phi,  0, -1];
    [-phi,  0,  1]
];

% Normalize to unit sphere
vertices = vertices ./ sqrt(sum(vertices.^2, 2));

% Basic icosahedron faces
faces = [
    [1, 12, 6]; [1, 6, 2]; [1, 2, 8]; [1, 8, 11]; [1, 11, 12];
    [2, 6, 10]; [6, 12, 5]; [12, 11, 3]; [11, 8, 7]; [8, 2, 9];
    [4, 10, 5]; [4, 5, 3]; [4, 3, 7]; [4, 7, 9]; [4, 9, 10];
    [5, 10, 6]; [3, 5, 12]; [7, 3, 11]; [9, 7, 8]; [10, 9, 2]
];

% Subdivide (simplified version)
for sub = 1:subdivisions
    new_vertices = vertices;
    new_faces = [];
    
    for f = 1:size(faces, 1)
        v1 = faces(f, 1);
        v2 = faces(f, 2);
        v3 = faces(f, 3);
        
        % Add midpoints
        mid12 = (vertices(v1, :) + vertices(v2, :)) / 2;
        mid23 = (vertices(v2, :) + vertices(v3, :)) / 2;
        mid31 = (vertices(v3, :) + vertices(v1, :)) / 2;
        
        % Normalize to sphere
        mid12 = mid12 / norm(mid12);
        mid23 = mid23 / norm(mid23);
        mid31 = mid31 / norm(mid31);
        
        % Add new vertices
        new_vertices = [new_vertices; mid12; mid23; mid31];
        n_verts = size(new_vertices, 1);
        
        % Create 4 new faces
        new_faces = [new_faces;
                     v1, n_verts-2, n_verts;
                     v2, n_verts-1, n_verts-2;
                     v3, n_verts, n_verts-1;
                     n_verts-2, n_verts-1, n_verts];
    end
    
    vertices = new_vertices;
    faces = new_faces;
end

% Create adjacency matrix from faces
actual_N = size(vertices, 1);
W = sparse(actual_N, actual_N);

for f = 1:size(faces, 1)
    v1 = faces(f, 1);
    v2 = faces(f, 2);
    v3 = faces(f, 3);
    
    W(v1, v2) = 1; W(v2, v1) = 1;
    W(v2, v3) = 1; W(v3, v2) = 1;
    W(v3, v1) = 1; W(v1, v3) = 1;
end

G = struct();
G.N = actual_N;
G.W = W;
if include_coords
    G.coords = vertices;
end
end

function G = createBrainLike(N, include_coords)
% Create brain-like folded surface (simplified version)

% Start with sphere and add folds
G_sphere = createSphere(N, true);

if include_coords
    coords = G_sphere.coords;
    
    % Add brain-like folding by modulating radius
    theta = atan2(coords(:, 2), coords(:, 1));
    phi = acos(coords(:, 3));
    
    % Add sulci and gyri patterns
    radius_modulation = 1 + 0.2 * sin(3 * theta) .* sin(2 * phi) + ...
                       0.1 * sin(7 * theta) .* cos(3 * phi);
    
    coords = coords .* radius_modulation;
else
    coords = [];
end

G = struct();
G.N = G_sphere.N;
G.W = G_sphere.W;
if include_coords
    G.coords = coords;
end
end

function G = createRandomGeometric(N, include_coords)
% Create random geometric graph using GSPBox if available

% Try to use GSPBox gsp_sensor function first
if exist('gsp_sensor', 'file')
    try
        % Create graph with GSPBox (keeps default GSPBox size)
        G_gsp = gsp_sensor();
        
        % Convert to our format
        G = struct();
        G.N = G_gsp.N;
        G.W = G_gsp.W;
        if include_coords && isfield(G_gsp, 'coords')
            G.coords = G_gsp.coords;
        end
        return;
    catch ME
        warning('GSPBox:Fallback', 'GSPBox gsp_sensor failed: %s. Using fallback implementation.', ME.message);
    end
end

% Fallback: Custom implementation
% Generate random coordinates
coords = rand(N, 2) * 10; % 2D coordinates

% Connect nodes within threshold distance
threshold = sqrt(50 / N); % Adjust threshold based on N
W = sparse(N, N);

for i = 1:N
    for j = i+1:N
        dist = norm(coords(i, :) - coords(j, :));
        if dist < threshold
            W(i, j) = 1;
            W(j, i) = 1;
        end
    end
end

G = struct();
G.N = N;
G.W = W;
if include_coords
    G.coords = coords(:, 1:2); % Only keep x,y for visualization
end
end

function G = createLattice(N, include_coords)
% Create regular lattice (simplified to 1D chain)

actual_N = N;

% Create coordinates
if include_coords
    coords = [(1:actual_N)', zeros(actual_N, 1)]; % 1D lattice in 2D space
else
    coords = [];
end

% Create adjacency matrix (chain)
W = sparse(actual_N, actual_N);
for i = 1:actual_N-1
    W(i, i+1) = 1;
    W(i+1, i) = 1;
end

G = struct();
G.N = actual_N;
G.W = W;
if include_coords
    G.coords = coords;
end
end

function G = createSwissRoll(N, include_coords)
% Create Swiss roll manifold using GSPBox if available

% Try to use GSPBox gsp_swiss_roll function first
if exist('gsp_swiss_roll', 'file')
    try
        % Create graph with GSPBox (keeps default GSPBox size)
        G_gsp = gsp_swiss_roll();
        
        % Convert to our format
        G = struct();
        G.N = G_gsp.N;
        G.W = G_gsp.W;
        if include_coords && isfield(G_gsp, 'coords')
            G.coords = G_gsp.coords;
        end
        return;
    catch ME
        warning('GSPBox:Fallback', 'GSPBox gsp_swiss_roll failed: %s. Using fallback implementation.', ME.message);
    end
end

% Fallback: Custom implementation
% Generate points on Swiss roll
t = rand(N, 1) * 3 * pi;
h = rand(N, 1) * 10;

x = t .* cos(t);
y = t .* sin(t);
z = h;
coords = [x, y, z];

% Create adjacency based on manifold distance (approximated by Euclidean)
threshold = sqrt(50 / N);
W = sparse(N, N);

for i = 1:N
    for j = i+1:N
        dist = norm(coords(i, :) - coords(j, :));
        if dist < threshold
            W(i, j) = 1;
            W(j, i) = 1;
        end
    end
end

G = struct();
G.N = N;
G.W = W;
if include_coords
    G.coords = coords;
end
end