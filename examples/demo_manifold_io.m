%% Manifold Read/Write Demo
% Demonstrates file I/O for bct.Manifold objects
%
% Supported formats:
%   - .obj  - Wavefront OBJ
%   - .glb  - Binary glTF
%   - .gltf - GL Transmission Format
%   - .stl  - STereoLithography
%   - .ply  - Polygon File Format
%   - .mat  - MATLAB data file
%   - .h5/.hdf5 - HDF5 format

%% Setup
bct_start;

%% Load test mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);
fprintf('Loaded mesh: %d vertices, %d faces\n', size(M.Vertices,1), size(M.Faces,1));

%% Method 1: Instance method syntax (recommended)
fprintf('\n--- Instance Method Syntax ---\n');

% Write to OBJ file
M.write('demo_output.obj');
fprintf('Written to demo_output.obj\n');

% Write to GLB file
M.write('demo_output.glb');
fprintf('Written to demo_output.glb\n');

% Write to HDF5 file
M.write('demo_output.h5');
fprintf('Written to demo_output.h5\n');

%% Method 2: Static method for reading
fprintf('\n--- Static Method for Reading ---\n');

% Read from OBJ
M_obj = bct.Manifold.read('demo_output.obj');
fprintf('Read OBJ: %d vertices, %d faces\n', size(M_obj.Vertices,1), size(M_obj.Faces,1));

% Read from GLB
M_glb = bct.Manifold.read('demo_output.glb');
fprintf('Read GLB: %d vertices, %d faces\n', size(M_glb.Vertices,1), size(M_glb.Faces,1));

% Read from HDF5
M_h5 = bct.Manifold.read('demo_output.h5');
fprintf('Read HDF5: %d vertices, %d faces\n', size(M_h5.Vertices,1), size(M_h5.Faces,1));

%% Method 3: Direct function call syntax (alternative)
fprintf('\n--- Direct Function Call Syntax ---\n');

% Using bct.manifold.write and bct.manifold.read
bct.manifold.write(M, 'demo_output_alt.obj');
fprintf('Written using bct.manifold.write()\n');

M_alt = bct.manifold.read('demo_output_alt.obj');
fprintf('Read using bct.manifold.read(): %d vertices, %d faces\n', ...
    size(M_alt.Vertices,1), size(M_alt.Faces,1));

%% Cleanup
fprintf('\n--- Cleanup ---\n');
delete('demo_output.obj');
delete('demo_output.glb');
delete('demo_output.h5');
delete('demo_output_alt.obj');
fprintf('Cleaned up demo files\n');

fprintf('\n✓ Demo complete!\n');
