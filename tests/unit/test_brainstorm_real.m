%% Test Real Brainstorm Import Functionality
% This script tests import with actual Brainstorm protocol data

clear; close all;
cd('c:\CodingProjects\bioctree');
bioctree_start;

fprintf('=== Testing Real Brainstorm Import ===\n\n');

bst_path = 'test-data/brainstorm';

if ~exist(bst_path, 'dir')
    fprintf('⚠ Brainstorm test data not found at: %s\n', bst_path);
    fprintf('Skipping real Brainstorm tests\n');
    return;
end

%% Test 1: Auto-detect protocol with default settings
fprintf('1. Auto-detect first subject (default cortex_pial_low)...\n');
try
    tic;
    B1 = bct.io.import.mesh(bst_path);
    t1 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t1);
    fprintf('   ✓ Vertices: %d, Faces: %d\n', size(B1.Manifold.V,1), size(B1.Manifold.F,1));
    fprintf('   ✓ Type: %s\n\n', B1.Manifold.Type);
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 2: Specify subject explicitly
fprintf('2. Load specific subject (sub-0002)...\n');
try
    tic;
    B2 = bct.io.import.mesh(bst_path, 'Subject', 'sub-0002');
    t2 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t2);
    fprintf('   ✓ Vertices: %d, Faces: %d\n\n', size(B2.Manifold.V,1), size(B2.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 3: High resolution import
fprintf('3. Load high resolution cortex_pial...\n');
try
    tic;
    B3 = bct.io.import.mesh(bst_path, 'Subject', 'sub-0002', 'Resolution', 'high');
    t3 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t3);
    fprintf('   ✓ Vertices: %d, Faces: %d\n', size(B3.Manifold.V,1), size(B3.Manifold.F,1));
    fprintf('   ✓ High-res has %.1fx more vertices than low-res\n\n', ...
        size(B3.Manifold.V,1) / size(B2.Manifold.V,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 4: White matter surface
fprintf('4. Load white matter surface (low)...\n');
try
    tic;
    B4 = bct.io.import.mesh(bst_path, 'Subject', 'sub-0002', 'Surface', 'white');
    t4 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t4);
    fprintf('   ✓ Vertices: %d, Faces: %d\n\n', size(B4.Manifold.V,1), size(B4.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 5: Mid surface
fprintf('5. Load mid surface...\n');
try
    tic;
    B5 = bct.io.import.mesh(bst_path, 'Subject', 'sub-0002', 'Surface', 'mid');
    t5 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t5);
    fprintf('   ✓ Vertices: %d, Faces: %d\n\n', size(B5.Manifold.V,1), size(B5.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 6: Head mask (non-cortex structure)
fprintf('6. Load head mask structure...\n');
try
    tic;
    B6 = bct.io.import.mesh(bst_path, 'Subject', 'sub-0002', 'Structure', 'head_mask');
    t6 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t6);
    fprintf('   ✓ Vertices: %d, Faces: %d\n\n', size(B6.Manifold.V,1), size(B6.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 7: Direct file path
fprintf('7. Load via direct file path...\n');
try
    direct_file = fullfile(bst_path, 'anat', 'sub-0002', 'tess_cortex_pial_low.mat');
    tic;
    B7 = bct.io.import.mesh(direct_file);
    t7 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t7);
    fprintf('   ✓ Vertices: %d, Faces: %d\n\n', size(B7.Manifold.V,1), size(B7.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 8: Graph-type Manifold (edges from faces)
fprintf('8. Import as graph-type Manifold...\n');
try
    tic;
    B8 = bct.io.import.graph(bst_path, 'Subject', 'sub-0002');
    t8 = toc;
    fprintf('   ✓ Success in %.2f sec\n', t8);
    fprintf('   ✓ Vertices: %d, Edges: %d\n', size(B8.Manifold.V,1), height(B8.Manifold.Edges));
    fprintf('   ✓ Type: %s\n\n', B8.Manifold.Type);
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Test 9: Format auto-detection
fprintf('9. Test format auto-detection...\n');
try
    % Should detect as Brainstorm from path
    format1 = bct.io.convert.detectFormat(bst_path);
    fprintf('   ✓ Protocol path detected as: %s\n', format1);
    
    % Should detect from tess_*.mat filename
    format2 = bct.io.convert.detectFormat('path/to/tess_cortex_pial_low.mat');
    fprintf('   ✓ tess_*.mat detected as: %s\n', format2);
    
    % Should detect from directory with anat/
    format3 = bct.io.convert.detectFormat(fullfile(bst_path, 'anat'));
    fprintf('   ✓ anat/ directory detected as: %s\n\n', format3);
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

%% Summary
fprintf('=== Test Summary ===\n');
if exist('B1', 'var')
    fprintf('Low-res pial:   %6d vertices, %6d faces\n', size(B1.Manifold.V,1), size(B1.Manifold.F,1));
end
if exist('B3', 'var')
    fprintf('High-res pial:  %6d vertices, %6d faces\n', size(B3.Manifold.V,1), size(B3.Manifold.F,1));
end
if exist('B4', 'var')
    fprintf('White surface:  %6d vertices, %6d faces\n', size(B4.Manifold.V,1), size(B4.Manifold.F,1));
end
if exist('B5', 'var')
    fprintf('Mid surface:    %6d vertices, %6d faces\n', size(B5.Manifold.V,1), size(B5.Manifold.F,1));
end
if exist('B6', 'var')
    fprintf('Head mask:      %6d vertices, %6d faces\n', size(B6.Manifold.V,1), size(B6.Manifold.F,1));
end
if exist('B8', 'var')
    fprintf('Graph (pial):   %6d vertices, %6d edges\n', size(B8.Manifold.V,1), height(B8.Manifold.Edges));
end

fprintf('\n✓ All tests completed!\n');

