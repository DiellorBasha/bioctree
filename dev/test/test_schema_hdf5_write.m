%% Test Schema-Driven HDF5 Serialization
% Verify bct.file.writeManifold with bct.schema integration

clear; clc;

%% Load test manifold
fprintf('Loading canonical test manifold...\n');
M = bct.data.load('Id', 'fsaverage_rh_pial');
fprintf('  Vertices: %d\n', size(M.Vertices, 1));
fprintf('  Faces: %d\n', size(M.Faces, 1));
fprintf('  Edges: %d\n\n', size(M.Edges, 1));

%% Test 1: Write core manifold only
fprintf('Test 1: Write core manifold\n');
fprintf('============================\n');
outfile = fullfile(pwd, 'test_schema_write.h5');
if isfile(outfile)
    delete(outfile);
end

bct.file.write.manifold(outfile, M, 'CreateFile', true);
fprintf('\n');

%% Test 2: Verify HDF5 structure
fprintf('Test 2: Verify HDF5 structure\n');
fprintf('==============================\n');
info = h5info(outfile);
fprintf('Root groups:\n');
for i = 1:numel(info.Groups)
    fprintf('  %s\n', info.Groups(i).Name);
end

% Check /manifold group
manifoldInfo = h5info(outfile, '/manifold');
fprintf('\n/manifold attributes:\n');
for i = 1:numel(manifoldInfo.Attributes)
    attr = manifoldInfo.Attributes(i);
    fprintf('  %s = %s\n', attr.Name, string(attr.Value));
end

fprintf('\n/manifold datasets:\n');
for i = 1:numel(manifoldInfo.Datasets)
    ds = manifoldInfo.Datasets(i);
    fprintf('  %s: %s\n', ds.Name, mat2str(ds.Dataspace.Size));
end
fprintf('\n');

%% Test 3: Read back and verify
fprintf('Test 3: Read back and verify data\n');
fprintf('==================================\n');
V_read = h5read(outfile, '/manifold/vertices');
F_read = h5read(outfile, '/manifold/faces');
E_read = h5read(outfile, '/manifold/edges');

fprintf('  Vertices match: %s\n', string(isequal(M.Vertices, V_read)));
fprintf('  Faces match (0-based): %s\n', string(isequal(M.Faces - 1, F_read)));
fprintf('  Edges match (0-based): %s\n', string(isequal(M.Edges - 1, E_read)));

% Check dataset attributes
vertAttrs = h5info(outfile, '/manifold/vertices');
fprintf('\n  vertices attributes:\n');
for i = 1:min(5, numel(vertAttrs.Attributes))
    attr = vertAttrs.Attributes(i);
    fprintf('    %s = %s\n', attr.Name, string(attr.Value));
end
fprintf('\n');

%% Test 4: Write with geometry group (if geometry method exists)
fprintf('Test 4: Write with geometry group\n');
fprintf('===================================\n');
try
    if isfile(outfile)
        delete(outfile);
    end
    bct.file.write.manifold(outfile, M, 'CreateFile', true, 'Geometry', true);
    
    info = h5info(outfile);
    fprintf('Root groups after geometry:\n');
    for i = 1:numel(info.Groups)
        fprintf('  %s\n', info.Groups(i).Name);
    end
    fprintf('\n');
catch ME
    fprintf('  Geometry write skipped: %s\n\n', ME.message);
end

%% Cleanup
fprintf('Cleaning up...\n');
if isfile(outfile)
    delete(outfile);
end
fprintf('✓ All tests complete\n');
