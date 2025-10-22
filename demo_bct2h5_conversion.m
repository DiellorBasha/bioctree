%% BCT to H5 Conversion Demo
% This script demonstrates converting legacy .bct files to proper .h5 HDF5 format
% for better system compatibility and file format recognition.

close all; clear; clc;

fprintf('=== BCT to H5 Conversion Demo ===\n\n');

%% Step 1: Create a demo .bct file (simulate legacy format)
fprintf('1. Creating demo legacy .bct file...\n');

% Get configuration
config = bioctree_config();

% Create a test .bct file (actually an HDF5 file with wrong extension)
testBctFile = fullfile(config.TempPath, 'demo_legacy_file.bct');

% Create some test data structure
testData = struct();
testData.signal = randn(50, 100); % 50 vertices, 100 time points
testData.time_vector = linspace(0, 2, 100);
testData.sampling_frequency = 50;

% Create HDF5 file with .bct extension (simulating legacy format)
h5create(testBctFile, '/data/signal', size(testData.signal));
h5write(testBctFile, '/data/signal', testData.signal);

h5create(testBctFile, '/temporal/time_vector', size(testData.time_vector));
h5write(testBctFile, '/temporal/time_vector', testData.time_vector);

h5create(testBctFile, '/temporal/sampling_frequency', 1);
h5write(testBctFile, '/temporal/sampling_frequency', testData.sampling_frequency);

% Add metadata to make it look like a Bioctree file
h5writeatt(testBctFile, '/', 'file_type', 'bioctree_legacy');
h5writeatt(testBctFile, '/', 'created_date', datestr(now));

fprintf('  ✓ Created: %s\n', testBctFile);
fileInfo = dir(testBctFile);
fprintf('  Size: %.2f KB\n', fileInfo.bytes / 1024);

% Verify it's actually HDF5 format
try
    h5info(testBctFile);
    fprintf('  ✓ File is valid HDF5 format (but has wrong .bct extension)\n');
catch
    fprintf('  ✗ File is not valid HDF5 format\n');
    return;
end

%% Step 2: Demonstrate single file conversion
fprintf('\n2. Converting single .bct file to .h5 format...\n');

% Convert the file
result = bct2h5(testBctFile, 'Verbose', true);

% Check results
if result.files_converted > 0
    h5File = strrep(testBctFile, '.bct', '.h5');
    fprintf('  ✓ Conversion successful!\n');
    fprintf('  Original: %s\n', testBctFile);
    fprintf('  Converted: %s\n', h5File);
    
    % Verify the converted file
    try
        h5Info = h5info(h5File);
        fprintf('  ✓ Converted file is valid HDF5\n');
        fprintf('  Groups: %d\n', length(h5Info.Groups));
        
        % Read some data to verify integrity
        convertedSignal = h5read(h5File, '/data/signal');
        originalSignal = h5read(testBctFile, '/data/signal');
        
        if isequal(convertedSignal, originalSignal)
            fprintf('  ✓ Data integrity verified\n');
        else
            fprintf('  ✗ Data integrity check failed\n');
        end
    catch ME
        fprintf('  ✗ Converted file verification failed: %s\n', ME.message);
    end
else
    fprintf('  ✗ Conversion failed\n');
    return;
end

%% Step 3: Demonstrate system identification
fprintf('\n3. Demonstrating file format identification...\n');

% Show how other systems can now identify the file format
fprintf('  Before conversion (.bct extension):\n');
[~, ~, bctExt] = fileparts(testBctFile);
fprintf('    Extension: %s\n', bctExt);
fprintf('    System recognition: Poor (unknown .bct format)\n');

fprintf('  After conversion (.h5 extension):\n');
[~, ~, h5Ext] = fileparts(h5File);
fprintf('    Extension: %s\n', h5Ext);
fprintf('    System recognition: Excellent (standard HDF5 format)\n');

% Demonstrate with MATLAB's built-in functions
fprintf('  MATLAB file identification:\n');
try
    % This works for both, but .h5 is more standard
    bctInfo = h5info(testBctFile);
    h5Info = h5info(h5File);
    
    fprintf('    Both files readable by h5info() ✓\n');
    fprintf('    .h5 files are recognized by more software\n');
    fprintf('    .h5 files follow HDF5 naming conventions\n');
catch
    fprintf('    File reading test failed\n');
end

%% Step 4: Demonstrate batch conversion capability
fprintf('\n4. Demonstrating batch conversion capability...\n');

% Create a few more demo .bct files
fprintf('  Creating additional demo .bct files...\n');
demoFiles = {
    fullfile(config.TempPath, 'subject01_session01.bct');
    fullfile(config.TempPath, 'subject01_session02.bct');
    fullfile(config.TempPath, 'subject02_session01.bct')
};

for i = 1:length(demoFiles)
    % Create simple HDF5 files with .bct extension
    demoFile = demoFiles{i};
    
    h5create(demoFile, '/data/demo', [10, 10]);
    h5write(demoFile, '/data/demo', randn(10, 10));
    h5writeatt(demoFile, '/', 'subject_id', sprintf('subject%02d', i));
    
    fprintf('    Created: %s\n', demoFile);
end

% Run batch conversion on the temp directory
fprintf('\n  Running batch conversion...\n');
batchResult = bct2h5(config.TempPath, 'Recursive', false, 'Verbose', false);

fprintf('  Batch conversion results:\n');
fprintf('    Files converted: %d\n', batchResult.files_converted);
fprintf('    Files failed: %d\n', batchResult.files_failed);
fprintf('    Total data: %.2f KB\n', batchResult.total_size_mb * 1024);

%% Step 5: Show data system integration
fprintf('\n5. Integration with Bioctree data system...\n');

% Show how the conversion integrates with the data management system
fprintf('  Current data system status:\n');
dataInfo = bioctree_data_info('summary');

fprintf('    Total files: %d\n', dataInfo.summary.total_files);
fprintf('    HDF5 (.h5) files: %d\n', dataInfo.summary.bioctree_h5_files + dataInfo.summary.other_h5_files);
fprintf('    Legacy (.bct) files: %d\n', dataInfo.summary.legacy_bct_files);

if dataInfo.summary.legacy_bct_files > 0
    fprintf('\n  Legacy files detected! Use bioctree_convert_data() to convert all at once.\n');
else
    fprintf('\n  ✓ No legacy files - system fully converted to .h5 format!\n');
end

%% Step 6: Cleanup and recommendations
fprintf('\n6. Cleanup and recommendations...\n');

% Clean up demo files
fprintf('  Cleaning up demo files...\n');
allDemoFiles = [testBctFile; demoFiles; strrep(demoFiles, '.bct', '.h5'); {h5File}];

for i = 1:length(allDemoFiles)
    if exist(allDemoFiles{i}, 'file')
        delete(allDemoFiles{i});
        fprintf('    Deleted: %s\n', allDemoFiles{i});
    end
end

fprintf('\n=== Recommendations ===\n');
fprintf('For existing Bioctree users:\n');
fprintf('• Use bct2h5() to convert individual legacy files\n');
fprintf('• Use bioctree_convert_data() for batch conversion of entire data system\n');
fprintf('• Always use .h5 extension for new Bioctree files\n');
fprintf('• The .h5 format ensures compatibility with other HDF5 software\n');
fprintf('• Your data structure and content remain exactly the same\n');

fprintf('\nFor new users:\n');
fprintf('• All new files automatically use .h5 format\n');
fprintf('• Use outbct() and inbct() functions normally\n');
fprintf('• Files are properly recognized as HDF5 by other software\n');

fprintf('\nSystem benefits:\n');
fprintf('• Better interoperability with other scientific software\n');
fprintf('• Proper file format identification by operating systems\n');
fprintf('• Standard HDF5 tools can inspect and analyze files\n');
fprintf('• Maintains all Bioctree-specific structure and metadata\n');

fprintf('\n=== Demo Complete ===\n');
fprintf('Your Bioctree files can now be properly identified as HDF5 format!\n\n');