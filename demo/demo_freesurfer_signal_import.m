%% FreeSurfer Signal Import Example
% Example demonstrating how to import FreeSurfer curvature signals into BCT

clear; clc;

fprintf('=== FreeSurfer Signal Import Demo ===\n\n');

%% 1. Import graph and signal separately, then combine
fprintf('1. Loading FreeSurfer surface mesh...\n');

% Load left hemisphere pial surface
mesh_path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
if exist(mesh_path, 'file')
    B = bct.io.graph.Import.fromFreeSurfer(mesh_path);
    fprintf('   ✅ Loaded mesh: %d vertices, %d faces\n', ...
        B.N, size(B.Faces, 1));
else
    fprintf('   ⚠️  Mesh file not found, creating empty BCT object\n');
    B = bct.bct();
end

%% 2. Import curvature signal
fprintf('\n2. Loading FreeSurfer curvature signal...\n');

curv_path = 'test-data\freesurfer\fsaverage\surf\lh.curv';
if exist(curv_path, 'file')
    B = bct.io.signal.Import.fromFreeSurfer(curv_path, B);
    fprintf('   ✅ Loaded curvature signal\n');
    fprintf('   Signal range: [%.4f, %.4f]\n', ...
        min(B.signals.data{1}), max(B.signals.data{1}));
else
    fprintf('   ⚠️  Curvature file not found: %s\n', curv_path);
    return;
end

%% 3. Import additional signals (if available)
fprintf('\n3. Looking for additional FreeSurfer signals...\n');

% Common FreeSurfer signal files
signal_files = {
    'test-data\freesurfer\fsaverage\surf\lh.sulc';    ... % Sulcal depth
    'test-data\freesurfer\fsaverage\surf\lh.thickness'; ... % Cortical thickness
    'test-data\freesurfer\fsaverage\surf\lh.area'     ... % Surface area
};

for i = 1:length(signal_files)
    if exist(signal_files{i}, 'file')
        try
            B = bct.io.signal.Import.fromFreeSurfer(signal_files{i}, B);
            [~, fname] = fileparts(signal_files{i});
            fprintf('   ✅ Loaded %s\n', fname);
        catch ME
            fprintf('   ❌ Failed to load %s: %s\n', signal_files{i}, ME.message);
        end
    end
end

fprintf('   Total signals loaded: %d\n', length(B.signals.data));

%% 4. Display signal information
fprintf('\n4. Signal stack summary:\n');

if ~isempty(B.signals.data)
    for i = 1:length(B.signals.data)
        signal = B.signals.data{i};
        meta = B.signals.metadata{i};
        
        fprintf('   Signal %d: %s\n', i, B.signals.labels{i});
        fprintf('     - Type: %s\n', meta.signal_type);
        fprintf('     - Hemisphere: %s\n', meta.hemisphere);
        fprintf('     - Values: %d (range: [%.4f, %.4f])\n', ...
            length(signal), min(signal), max(signal));
        fprintf('     - Data type: %s\n', meta.data_type);
        fprintf('     - Source: %s\n', meta.source_file);
    end
else
    fprintf('   No signals in stack\n');
end

%% 5. Demonstrate signal access methods
fprintf('\n5. Demonstrating signal access:\n');

if ~isempty(B.signals.data)
    % Access by index
    curvature = B.getSignal(1);
    fprintf('   Retrieved signal 1 by index: %d values\n', length(curvature));
    
    % Access by label
    try
        label = B.signals.labels{1};
        same_signal = B.getSignal(label);
        fprintf('   Retrieved same signal by label "%s": %d values\n', ...
            label, length(same_signal));
        
        if isequal(curvature, same_signal)
            fprintf('   ✅ Index and label access return identical data\n');
        end
    catch ME
        fprintf('   ❌ Label access failed: %s\n', ME.message);
    end
end

%% 6. Optional: Demonstrate signal processing
fprintf('\n6. Basic signal statistics:\n');

if ~isempty(B.signals.data)
    for i = 1:length(B.signals.data)
        signal = B.signals.data{i};
        label = B.signals.labels{i};
        
        fprintf('   %s:\n', label);
        fprintf('     - Mean: %.6f\n', mean(signal));
        fprintf('     - Std:  %.6f\n', std(signal));
        fprintf('     - Min:  %.6f\n', min(signal));
        fprintf('     - Max:  %.6f\n', max(signal));
        
        % Count positive/negative values for curvature
        if contains(lower(label), 'curv')
            pos_count = sum(signal > 0);
            neg_count = sum(signal < 0);
            fprintf('     - Convex regions (curv > 0): %d vertices\n', pos_count);
            fprintf('     - Concave regions (curv < 0): %d vertices\n', neg_count);
        end
    end
end

fprintf('\n=== Demo Complete ===\n');
fprintf('\nUsage summary:\n');
fprintf('  • Import signal only: B = bct.io.signal.Import.fromFreeSurfer(path)\n');
fprintf('  • Add to existing BCT: B = bct.io.signal.Import.fromFreeSurfer(path, existing_B)\n');
fprintf('  • Access signals: signal = B.getSignal(index_or_label)\n');
fprintf('  • View signal stack: B.signals\n');