%TEST_MANIFOLD_OUT_STRUCT Test bct.manifold.out with 'struct' target type
%
% Tests that:
% 1. bct.manifold.out(M, 'struct') returns all public properties
% 2. Only computed cached properties are included
% 3. Structure contains expected fields

% Load canonical test manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');

fprintf('Testing bct.manifold.out with struct export...\n\n');

%% Test 1: Export with minimal cache (just loaded)
fprintf('Test 1: Export with minimal cache\n');
M1 = bct.data.load('Id', 'fsaverage_rh_pial');
out1 = bct.manifold.out(M1, 'struct');

% Check public properties
assert(isfield(out1, 'Vertices'), 'Missing Vertices field');
assert(isfield(out1, 'Faces'), 'Missing Faces field');
assert(isfield(out1, 'Edges'), 'Missing Edges field');
assert(isfield(out1, 'ID'), 'Missing ID field');
assert(isfield(out1, 'Metric'), 'Missing Metric field');
fprintf('  ✓ All public properties exported\n');

% Check that Vertices and Faces match
assert(isequal(out1.Vertices, M1.Vertices), 'Vertices mismatch');
assert(isequal(out1.Faces, M1.Faces), 'Faces mismatch');
assert(isequal(out1.Edges, M1.Edges), 'Edges mismatch');
fprintf('  ✓ Property values match source manifold\n');

fprintf('\n');

%% Test 2: Export with geometry cache populated
fprintf('Test 2: Export with geometry cache populated\n');
M2 = bct.data.load('Id', 'fsaverage_rh_pial');

% Populate geometry cache
geom = M2.geometry();

% Export to struct
out2 = bct.manifold.out(M2, 'struct');

% Check that geometry is included
assert(isfield(out2, 'geometry'), 'Missing geometry field');
fprintf('  ✓ Geometry cache exported\n');

% Verify geometry contents
assert(isfield(out2.geometry, 'centroids'), 'Missing centroids in geometry');
assert(isfield(out2.geometry, 'normals'), 'Missing normals in geometry');
assert(isfield(out2.geometry, 'vertexNormals'), 'Missing vertexNormals in geometry');
fprintf('  ✓ Geometry contains expected fields\n');

fprintf('\n');

%% Test 3: Export with operators cache populated
fprintf('Test 3: Export with operators cache populated\n');
M3 = bct.data.load('Id', 'fsaverage_rh_pial');

% Populate operators cache
ops = M3.operators();

% Export to struct
out3 = bct.manifold.out(M3, 'struct');

% Check that operators are included
assert(isfield(out3, 'operators'), 'Missing operators field');
fprintf('  ✓ Operators cache exported\n');

% Verify operators contents (flattened structure)
assert(isfield(out3.operators, 'mass'), 'Missing mass in operators');
assert(isfield(out3.operators, 'stiffness'), 'Missing stiffness in operators');
assert(isfield(out3.operators, 'd0'), 'Missing d0 in operators');
assert(isfield(out3.operators, 'hd1'), 'Missing hd1 in operators');
assert(isfield(out3.operators, 'gradient'), 'Missing gradient in operators');
fprintf('  ✓ Operators contains expected fields (flattened structure)\n');

% Verify no nested 'dec' field
if isfield(out3.operators, 'dec')
    error('FAILED: operators should not have nested dec field');
end
fprintf('  ✓ No nested dec structure (flattened as expected)\n');

fprintf('\n');

%% Test 4: Export with eigenmodes cache populated
fprintf('Test 4: Export with eigenmodes cache populated\n');
M4 = bct.data.load('Id', 'fsaverage_rh_pial');

% Populate eigenmodes cache
[lambda, U] = M4.eigenmodes(50);

% Export to struct
out4 = bct.manifold.out(M4, 'struct');

% Check that eigenmodes are included
assert(isfield(out4, 'eigenmodes'), 'Missing eigenmodes field');
fprintf('  ✓ Eigenmodes cache exported\n');

% Verify eigenmodes contents
assert(isfield(out4.eigenmodes, 'values'), 'Missing values in eigenmodes');
assert(isfield(out4.eigenmodes, 'vectors'), 'Missing vectors in eigenmodes');
fprintf('  ✓ Eigenmodes contains expected fields\n');

fprintf('\n');

%% Test 5: Export with topology cache populated
fprintf('Test 5: Export with topology cache populated\n');
M5 = bct.data.load('Id', 'fsaverage_rh_pial');

% Populate topology cache
topo = M5.topology();

% Export to struct
out5 = bct.manifold.out(M5, 'struct');

% Check that topology is included
assert(isfield(out5, 'topology'), 'Missing topology field');
fprintf('  ✓ Topology cache exported\n');

% Verify topology contents
assert(isfield(out5.topology, 'adjacencyMatrix'), 'Missing adjacencyMatrix in topology');
fprintf('  ✓ Topology contains expected fields\n');

fprintf('\n');

%% Test 6: Full export with all caches populated
fprintf('Test 6: Full export with all caches populated\n');
M6 = bct.data.load('Id', 'fsaverage_rh_pial');

% Populate all caches
geom = M6.geometry();
topo = M6.topology();
ops = M6.operators();
[lambda, U] = M6.eigenmodes(50);

% Export to struct
out6 = bct.manifold.out(M6, 'struct');

% Check all fields present
assert(isfield(out6, 'Vertices'), 'Missing Vertices');
assert(isfield(out6, 'Faces'), 'Missing Faces');
assert(isfield(out6, 'Edges'), 'Missing Edges');
assert(isfield(out6, 'ID'), 'Missing ID');
assert(isfield(out6, 'Metric'), 'Missing Metric');
assert(isfield(out6, 'geometry'), 'Missing geometry');
assert(isfield(out6, 'topology'), 'Missing topology');
assert(isfield(out6, 'operators'), 'Missing operators');
assert(isfield(out6, 'eigenmodes'), 'Missing eigenmodes');
fprintf('  ✓ All fields present in full export\n');

fprintf('\n');
fprintf('========================================\n');
fprintf('ALL TESTS PASSED ✓\n');
fprintf('bct.manifold.out struct export working correctly.\n');
fprintf('========================================\n');
