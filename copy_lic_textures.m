%% Copy LIC Textures to test-data/mesh
% This script copies the generated LIC textures from the output directory 
% to test-data/mesh/ for easier access and version control

clear; clc;

%% Configuration
SOURCE_DIR = 'output/lic_textures';
TARGET_DIR = 'test-data/mesh';

% Ensure target directory exists
if ~exist(TARGET_DIR, 'dir')
    mkdir(TARGET_DIR);
    fprintf('Created target directory: %s\n', TARGET_DIR);
end

fprintf('=== Copying LIC Textures to test-data/mesh ===\n\n');

%% Define files to copy
% LIC texture files (PNG format)
lic_files = {
    'lh_lic_texture.png'           % Left hemisphere LIC texture
    'rh_lic_texture.png'           % Right hemisphere LIC texture (if exists)
    'lh_pial_with_uv_lic.png'      % GLB pipeline LH texture
    'rh_pial_with_uv_lic.png'      % GLB pipeline RH texture
    'bilateral_pial_with_uv_lic.png' % Bilateral texture
};

% Supporting files
support_files = {
    'lh_uv_coords.npz'             % UV coordinates
    'rh_uv_coords.npz'             % RH UV coordinates
    'lh_uv_coords.mat'             % MATLAB format UV coords
    'lh_visualization.png'         % Analysis visualization
    'rh_visualization.png'         % RH visualization
};

% GLB files with embedded textures
glb_files = {
    'lh_pial_with_lic.glb'         % LH GLB with embedded LIC
    'rh_pial_with_lic.glb'         % RH GLB with embedded LIC
    'bilateral_pial_with_lic.glb'  % Bilateral GLB with embedded LIC
};

%% Copy LIC Textures
fprintf('Copying LIC texture files...\n');
copied_lic = 0;
for i = 1:length(lic_files)
    source_file = fullfile(SOURCE_DIR, lic_files{i});
    target_file = fullfile(TARGET_DIR, lic_files{i});
    
    if exist(source_file, 'file')
        try
            copyfile(source_file, target_file);
            fprintf('  ✓ Copied: %s\n', lic_files{i});
            copied_lic = copied_lic + 1;
        catch ME
            fprintf('  ✗ Failed to copy %s: %s\n', lic_files{i}, ME.message);
        end
    else
        fprintf('  - Not found: %s\n', lic_files{i});
    end
end

%% Copy Supporting Files
fprintf('\nCopying supporting files...\n');
copied_support = 0;
for i = 1:length(support_files)
    source_file = fullfile(SOURCE_DIR, support_files{i});
    target_file = fullfile(TARGET_DIR, support_files{i});
    
    if exist(source_file, 'file')
        try
            copyfile(source_file, target_file);
            fprintf('  ✓ Copied: %s\n', support_files{i});
            copied_support = copied_support + 1;
        catch ME
            fprintf('  ✗ Failed to copy %s: %s\n', support_files{i}, ME.message);
        end
    else
        fprintf('  - Not found: %s\n', support_files{i});
    end
end

%% Copy GLB Files
fprintf('\nCopying GLB files with embedded textures...\n');
copied_glb = 0;
for i = 1:length(glb_files)
    source_file = fullfile(SOURCE_DIR, glb_files{i});
    target_file = fullfile(TARGET_DIR, glb_files{i});
    
    if exist(source_file, 'file')
        try
            copyfile(source_file, target_file);
            fprintf('  ✓ Copied: %s\n', glb_files{i});
            copied_glb = copied_glb + 1;
        catch ME
            fprintf('  ✗ Failed to copy %s: %s\n', glb_files{i}, ME.message);
        end
    else
        fprintf('  - Not found: %s\n', glb_files{i});
    end
end

%% Create README for the copied files
readme_content = {
    '# LIC Textures for Cortical Visualization'
    ''
    'This directory contains Line Integral Convolution (LIC) textures generated'
    'from FreeSurfer cortical surfaces for three.js visualization.'
    ''
    '## LIC Texture Files'
    ''
    '### Main LIC Textures (4096×2048 PNG)'
    '- `lh_lic_texture.png` - Left hemisphere LIC texture'
    '- `rh_lic_texture.png` - Right hemisphere LIC texture'
    ''
    '### GLB Pipeline Textures'
    '- `lh_pial_with_uv_lic.png` - LH texture from GLB pipeline'
    '- `rh_pial_with_uv_lic.png` - RH texture from GLB pipeline'
    '- `bilateral_pial_with_uv_lic.png` - Combined hemispheres texture'
    ''
    '## GLB Files with Embedded Textures'
    '- `lh_pial_with_lic.glb` - LH mesh with embedded LIC texture'
    '- `rh_pial_with_lic.glb` - RH mesh with embedded LIC texture'
    '- `bilateral_pial_with_lic.glb` - Combined mesh with embedded LIC texture'
    ''
    '## Supporting Files'
    '- `lh_uv_coords.npz` - UV coordinates for texture mapping'
    '- `lh_visualization.png` - Analysis and visualization plots'
    ''
    '## Usage in three.js'
    ''
    '### Using PNG Textures'
    '```javascript'
    'const textureLoader = new THREE.TextureLoader();'
    'const licTexture = textureLoader.load("lh_lic_texture.png");'
    'const material = new THREE.MeshBasicMaterial({ map: licTexture });'
    '```'
    ''
    '### Using GLB Files'
    '```javascript'
    'const loader = new GLTFLoader();'
    'loader.load("lh_pial_with_lic.glb", (gltf) => {'
    '    scene.add(gltf.scene);'
    '});'
    '```'
    ''
    '## Generation Pipeline'
    ''
    'These textures were generated using:'
    '1. FreeSurfer cortical surfaces (lh.pial, rh.pial)'
    '2. Spherical parameterization (lh.sphere.reg, rh.sphere.reg)'
    '3. Surface-tangent vector field generation'
    '4. Line Integral Convolution (LIC) algorithm'
    ''
    'For more details, see the main README_LIC_Pipeline.md file.'
    ''
    sprintf('Generated on: %s', datestr(now))
};

readme_file = fullfile(TARGET_DIR, 'README_LIC_TEXTURES.md');
fid = fopen(readme_file, 'w');
if fid ~= -1
    for i = 1:length(readme_content)
        fprintf(fid, '%s\n', readme_content{i});
    end
    fclose(fid);
    fprintf('\n  ✓ Created README: README_LIC_TEXTURES.md\n');
else
    fprintf('\n  ✗ Failed to create README file\n');
end

%% Summary
fprintf('\n=== Copy Summary ===\n');
fprintf('LIC textures copied: %d/%d\n', copied_lic, length(lic_files));
fprintf('Support files copied: %d/%d\n', copied_support, length(support_files));
fprintf('GLB files copied: %d/%d\n', copied_glb, length(glb_files));
fprintf('Target directory: %s\n', TARGET_DIR);

if copied_lic == 0
    fprintf('\n⚠️  No LIC textures found!\n');
    fprintf('Make sure to run the LIC generation pipeline first:\n');
    fprintf('  1. MATLAB: export_surfaces_for_lic_glb\n');
    fprintf('  2. Python: python generate_lic_texture.py\n');
    fprintf('  3. Or: run_lic_generation.bat\n');
else
    fprintf('\n✅ LIC textures successfully copied to test-data/mesh/\n');
    fprintf('The textures are ready for use in three.js visualization!\n');
end

% Open target directory in explorer
if copied_lic > 0 || copied_glb > 0
    if ispc
        try
            winopen(TARGET_DIR);
        catch
            fprintf('Could not open directory automatically\n');
        end
    end
end