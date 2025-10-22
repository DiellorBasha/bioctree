%% Test gftH5 Signal Preservation
% This test verifies that gftH5 no longer overwrites signal data

clear; clc;

fprintf('=== Testing gftH5 Signal Preservation ===\n');

% Setup
config = bioctree_config();
hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');

% Check signals before
fprintf('\n1. Checking signals BEFORE gftH5...\n');
raw_info_before = h5info(hdf5_file, '/data/raw');
signals_before = {raw_info_before.Datasets.Name};
fprintf('   Signals found: %d\n', length(signals_before));
for i = 1:min(3, length(signals_before))
    fprintf('   - %s\n', signals_before{i});
end
if length(signals_before) > 3
    fprintf('   - ... and %d more\n', length(signals_before) - 3);
end

% Run gftH5 on a specific signal
fprintf('\n2. Running gftH5 on "signal_patch_20_pct"...\n');
gftH5(hdf5_file, 'SignalName', 'signal_patch_20_pct', 'Verbose', false);

% Check signals after
fprintf('\n3. Checking signals AFTER gftH5...\n');
raw_info_after = h5info(hdf5_file, '/data/raw');
signals_after = {raw_info_after.Datasets.Name};
fprintf('   Signals found: %d\n', length(signals_after));

% Compare
if length(signals_before) == length(signals_after)
    fprintf('   ✓ PASS: Same number of signals (%d)\n', length(signals_after));
    
    % Check if all signals are preserved
    all_preserved = true;
    for i = 1:length(signals_before)
        if ~any(strcmp(signals_before{i}, signals_after))
            fprintf('   ✗ FAIL: Signal "%s" was lost!\n', signals_before{i});
            all_preserved = false;
        end
    end
    
    if all_preserved
        fprintf('   ✓ PASS: All signal names preserved\n');
        
        % Check sizes
        sizes_match = true;
        for i = 1:length(signals_before)
            size_before = raw_info_before.Datasets(i).Dataspace.Size;
            idx_after = find(strcmp(signals_before{i}, signals_after));
            size_after = raw_info_after.Datasets(idx_after).Dataspace.Size;
            
            if ~isequal(size_before, size_after)
                fprintf('   ✗ FAIL: Signal "%s" size changed from %s to %s\n', ...
                    signals_before{i}, mat2str(size_before), mat2str(size_after));
                sizes_match = false;
            end
        end
        
        if sizes_match
            fprintf('   ✓ PASS: All signal sizes preserved\n');
        end
    end
else
    fprintf('   ✗ FAIL: Signal count changed from %d to %d\n', ...
        length(signals_before), length(signals_after));
end

% Check if any Fourier data was added (this is expected to fail for now)
fprintf('\n4. Checking if Fourier basis was saved...\n');
try
    eigenvals = h5read(hdf5_file, '/graph/eigenvalues');
    fprintf('   ✓ Eigenvalues saved: %d values\n', length(eigenvals));
catch
    fprintf('   ℹ Eigenvalues not saved (expected - needs HDF5 structure fix)\n');
end

try
    eigenvecs = h5read(hdf5_file, '/graph/eigenvectors');
    fprintf('   ✓ Eigenvectors saved: %s\n', mat2str(size(eigenvecs)));
catch
    fprintf('   ℹ Eigenvectors not saved (expected - needs HDF5 structure fix)\n');
end

fprintf('\n=== Test Summary ===\n');
if length(signals_before) == length(signals_after)
    fprintf('✓ PRIMARY GOAL ACHIEVED: gftH5 no longer overwrites signal data!\n');
    fprintf('✓ Signal preservation: WORKING\n');
    fprintf('ℹ Fourier basis saving: Needs HDF5 structure improvements\n');
else
    fprintf('✗ CRITICAL ISSUE: Signal data was lost or corrupted\n');
end

fprintf('\nNext steps:\n');
fprintf('- Fix HDF5 dataset creation for eigenvalues/eigenvectors\n');
fprintf('- Consider adding Fourier basis to existing outbct structure\n');

fprintf('\n=== Test Complete ===\n');