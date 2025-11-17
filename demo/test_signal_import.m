%% Test FreeSurfer Signal Import
% Test script to verify the new signal import functionality

clear; clc;

fprintf('=== Testing FreeSurfer Signal Import ===\n\n');

%% Test 1: Import FreeSurfer curvature file
signalpath = 'test-data\freesurfer\fsaverage\surf\lh.curv';

if ~exist(signalpath, 'file')
    fprintf('⚠️  Test file not found: %s\n', signalpath);
    fprintf('Please ensure the test data is available.\n');
    return;
end

fprintf('1. Testing signal import from: %s\n', signalpath);

try
    % Import signal using the new pipeline
    B = bct.io.signal.Import.fromFreeSurfer(signalpath);
    
    fprintf('✅ Signal import successful!\n');
    fprintf('   Vertices (N): %d\n', B.N);
    fprintf('   Signals in stack: %d\n', length(B.signals.data));
    
    if ~isempty(B.signals.data)
        fprintf('   Signal 1 label: %s\n', B.signals.labels{1});
        fprintf('   Signal 1 range: [%.4f, %.4f]\n', ...
            min(B.signals.data{1}), max(B.signals.data{1}));
        
        % Display metadata
        meta = B.signals.metadata{1};
        fprintf('   Metadata:\n');
        fprintf('     - Hemisphere: %s\n', meta.hemisphere);
        fprintf('     - Signal type: %s\n', meta.signal_type);
        fprintf('     - Data type: %s\n', meta.data_type);
        fprintf('     - Import date: %s\n', meta.import_date);
    end
    
catch ME
    fprintf('❌ Error during import: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

%% Test 2: Test signal retrieval methods
fprintf('\n2. Testing signal retrieval methods...\n');

try
    if exist('B', 'var') && ~isempty(B.signals.data)
        % Get signal by index
        signal1 = B.getSignal(1);
        fprintf('✅ Retrieved signal by index: %d values\n', length(signal1));
        
        % Get signal by label
        label = B.signals.labels{1};
        signal2 = B.getSignal(label);
        fprintf('✅ Retrieved signal by label "%s": %d values\n', label, length(signal2));
        
        % Verify they're the same
        if isequal(signal1, signal2)
            fprintf('✅ Index and label retrieval return identical data\n');
        else
            fprintf('❌ Mismatch between index and label retrieval\n');
        end
    end
    
catch ME
    fprintf('❌ Error during signal retrieval: %s\n', ME.message);
end

%% Test 3: Test adding to existing BCT object
fprintf('\n3. Testing addition to existing BCT object...\n');

try
    % Create a minimal BCT with graph data first
    graph_path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
    if exist(graph_path, 'file')
        B_graph = bct.io.graph.Import.fromFreeSurfer(graph_path);
        fprintf('   Created BCT with graph: %d vertices\n', B_graph.N);
        
        % Add signal to existing object
        B_combined = bct.io.signal.Import.fromFreeSurfer(signalpath, B_graph);
        fprintf('✅ Added signal to existing BCT object\n');
        fprintf('   Final vertices (N): %d\n', B_combined.N);
        fprintf('   Signals in stack: %d\n', length(B_combined.signals.data));
        if ~isempty(B_combined.Vertices)
            fprintf('   Has graph data: Yes\n');
        else
            fprintf('   Has graph data: No\n');
        end
    else
        fprintf('⚠️  Graph test file not found: %s\n', graph_path);
    end
    
catch ME
    fprintf('❌ Error during combined import: %s\n', ME.message);
end

fprintf('\n=== Test Complete ===\n');