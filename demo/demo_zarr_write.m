%% Demo: Writing Manifold to Zarr Format
% Demonstrates schema-driven Zarr serialization with BCT toolbox
%
% Features:
%   - Core manifold data (vertices, faces, edges)
%   - Geometry, topology, operators (when implemented)
%   - Eigenmodes with chunking (100 modes per chunk)
%   - Sparse matrices stored as COO format
%   - Format auto-detection from extension

clear; clc;

fprintf('=== BCT Zarr Write Demo ===\n\n');

%% Load Manifold
fprintf('1. Loading manifold...\n');
M = bct.data.load('Dataset', 'fsaverage6', 'Hemi', 'rh', 'Surface', 'pial');
fprintf('   Loaded: %d vertices, %d faces\n\n', ...
    size(M.Vertices, 1), size(M.Faces, 1));

%% Example 1: Write Core Manifold Only (WORKS NOW)
fprintf('2. Writing core manifold data...\n');
zarrPath1 = 'demo_core.zarr';

% Simple write - just vertices, faces, edges
bct.file.write.manifold(zarrPath1, M);

fprintf('   ✓ Saved to: %s\n', zarrPath1);
fprintf('   Structure:\n');
fprintf('     manifold/\n');
fprintf('       vertices/  (float32, %d vertices)\n', size(M.Vertices, 1));
fprintf('       faces/     (uint32, %d faces, 0-based indexing)\n', size(M.Faces, 1));
fprintf('       edges/     (uint32, %d edges, 0-based indexing)\n\n', size(M.Edges, 1));

%% Example 2: Complete Write (FUTURE - when Manifold methods exist)
fprintf('3. Complete write with all groups (future)...\n');
fprintf('   When Manifold.geometry/topology/operators/eigenmodes methods exist:\n\n');

fprintf('   Code example:\n');
fprintf('   --------------------------------------------------------\n');
fprintf('   %% Compute all groups\n');
fprintf('   geom = M.geometry();      %% Compute geometry\n');
fprintf('   topo = M.topology();      %% Compute topology\n');
fprintf('   ops = M.operators();      %% Compute operators\n');
fprintf('   [lambda, U] = M.eigenmodes(200);  %% Compute 200 eigenmodes\n\n');

fprintf('   %% Write everything (auto-detects computed groups)\n');
fprintf('   bct.file.write.manifold(''mesh.zarr'', M);\n\n');

fprintf('   %% OR force computation and write specific groups\n');
fprintf('   bct.file.write.manifold(''mesh_full.zarr'', M, ...\n');
fprintf('       ''Geometry'', true, ...\n');
fprintf('       ''Topology'', true, ...\n');
fprintf('       ''Operators'', true, ...\n');
fprintf('       ''Eigenmodes'', true, ...\n');
fprintf('       ''NumModes'', 200, ...\n');
fprintf('       ''ChunkSize'', 100);\n');
fprintf('   --------------------------------------------------------\n\n');

fprintf('   Expected Zarr structure:\n');
fprintf('     mesh.zarr/\n');
fprintf('       .zgroup, .zattrs (root metadata)\n');
fprintf('       manifold/           (vertices, faces, edges)\n');
fprintf('       geometry/           (normals, areas, centroids, etc.)\n');
fprintf('         vertex/normals, areas, ...\n');
fprintf('         face/normals, areas, centroids, ...\n');
fprintf('         edge/lengths, midpoints, ...\n');
fprintf('       topology/           (adjacency, boundary, halfedge)\n');
fprintf('         adjacency/        (sparse COO: row/, col/, data/)\n');
fprintf('         boundary/vertices, edges\n');
fprintf('         halfedge/next, twin\n');
fprintf('       operators/          (mass, stiffness, laplacian, DEC)\n');
fprintf('         mass/             (sparse COO: row/, col/, data/)\n');
fprintf('         stiffness/        (sparse COO)\n');
fprintf('         laplacian/        (sparse COO)\n');
fprintf('         d0, d1, dd0, dd1/ (DEC operators in COO)\n');
fprintf('       eigenmodes/         (eigenvalues, eigenvectors)\n');
fprintf('         eigenvalues/      (1D float64 array)\n');
fprintf('         eigenvectors/     (2D float64, chunked by 100 modes)\n');
fprintf('           0.0             (modes 1-100)\n');
fprintf('           0.1             (modes 101-200)\n\n');

%% Example 3: Format Detection
fprintf('4. Format auto-detection...\n');

% HDF5 format
h5File = 'demo_format.h5';
bct.file.write.manifold(h5File, M);
fprintf('   ✓ .h5 extension  → HDF5 format: %s\n', h5File);

% Zarr format
zarrPath2 = 'demo_format.zarr';
bct.file.write.manifold(zarrPath2, M);
fprintf('   ✓ .zarr extension → Zarr format: %s\n', zarrPath2);

% Explicit format specification
bct.file.write.manifold('demo_explicit', M, 'Format', 'zarr');
fprintf('   ✓ Explicit ''Format'', ''zarr'' → demo_explicit\n\n');

%% Example 4: Modular Write (write specific components)
fprintf('5. Modular component writing...\n');
zarrPath3 = 'demo_modular.zarr';

% Write only core
bct.file.write.manifold.zarr.core(zarrPath3, M);
fprintf('   ✓ Core only: bct.file.write.manifold.zarr.core()\n');

% Future: write specific groups
fprintf('   Future modular writes:\n');
fprintf('     bct.file.write.manifold.zarr.geometry(zarr, M)\n');
fprintf('     bct.file.write.manifold.zarr.topology(zarr, M)\n');
fprintf('     bct.file.write.manifold.zarr.operators(zarr, M)\n');
fprintf('     bct.file.write.manifold.zarr.eigenmodes(zarr, M, ''NumModes'', 200)\n\n');

%% Key Features Summary
fprintf('=== Key Zarr Features ===\n\n');

fprintf('✓ Sparse Matrices as COO:\n');
fprintf('  - Operators (mass, stiffness, laplacian)\n');
fprintf('  - Topology (adjacency matrix)\n');
fprintf('  - Format: row/, col/, data/ as separate arrays\n');
fprintf('  - 0-based indexing for row/col (GPU-friendly)\n\n');

fprintf('✓ Eigenmodes Chunking:\n');
fprintf('  - Default chunk size: 100 modes\n');
fprintf('  - Enables streaming and progressive loading\n');
fprintf('  - Customizable: ''ChunkSize'', 50\n\n');

fprintf('✓ Index Conversion:\n');
fprintf('  - MATLAB (1-based) → Zarr (0-based) automatic\n');
fprintf('  - Applies to faces, edges, and COO indices\n\n');

fprintf('✓ GPU-Friendly Format:\n');
fprintf('  - Float32 for vertices (float64 optional)\n');
fprintf('  - C-order (row-major) layout\n');
fprintf('  - Interleaved data for Three.js/WebGL\n\n');

fprintf('✓ Schema-Driven:\n');
fprintf('  - Automatic attribute mapping\n');
fprintf('  - Metadata preservation (units, support, etc.)\n');
fprintf('  - Consistent with HDF5 schema\n\n');

%% Inspect Created Zarr
fprintf('=== Inspecting Created Zarr ===\n\n');

fprintf('Core manifold structure:\n');
fprintf('  %s/\n', zarrPath1);
if isfolder(fullfile(zarrPath1, 'manifold'))
    fprintf('    manifold/\n');
    if isfolder(fullfile(zarrPath1, 'manifold', 'vertices'))
        % Read .zarray to show metadata
        zarrayFile = fullfile(zarrPath1, 'manifold', 'vertices', '.zarray');
        if isfile(zarrayFile)
            zarray = jsondecode(fileread(zarrayFile));
            fprintf('      vertices/ (.zarray)\n');
            fprintf('        shape:  %s\n', mat2str(zarray.shape));
            fprintf('        dtype:  %s\n', zarray.dtype);
            fprintf('        chunks: %s\n', mat2str(zarray.chunks));
        end
    end
    if isfolder(fullfile(zarrPath1, 'manifold', 'faces'))
        fprintf('      faces/ (0-based indexing)\n');
    end
    if isfolder(fullfile(zarrPath1, 'manifold', 'edges'))
        fprintf('      edges/ (0-based indexing)\n');
    end
end
fprintf('\n');

%% Cleanup
fprintf('=== Cleanup ===\n');
fprintf('Removing demo files...\n');

if isfolder(zarrPath1), rmdir(zarrPath1, 's'); end
if isfile(h5File), delete(h5File); end
if isfolder(zarrPath2), rmdir(zarrPath2, 's'); end
if isfolder('demo_explicit'), rmdir('demo_explicit', 's'); end
if isfolder(zarrPath3), rmdir(zarrPath3, 's'); end

fprintf('✓ Done!\n\n');

fprintf('=== Next Steps ===\n');
fprintf('Once Manifold class has geometry/topology/operators/eigenmodes methods:\n');
fprintf('  1. Compute the groups you want: geom = M.geometry();\n');
fprintf('  2. Write to Zarr: bct.file.write.manifold(''mesh.zarr'', M);\n');
fprintf('  3. Zarr auto-detects what''s computed and writes it all!\n');
