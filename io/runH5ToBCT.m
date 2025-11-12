%% H5 to BCT Conversion Script
% Load MEG data from H5 file and convert to enhanced BCT format

clear; clc;

% Add bioctree to path
addpath(genpath('.'));

% Input and output files
sourceFile = 'data/bioctree_files/raw/sub-0002.h5';
bctFile = 'data/bioctree_files/processed/sub-0002_enhanced.bct.h5';

% Ensure output directory exists
outputDir = fileparts(bctFile);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Run the conversion pipeline
fprintf('Starting H5 to BCT conversion...\n');
fprintf('Source: %s\n', sourceFile);
fprintf('Target: %s\n', bctFile);

try
    loadH5ToBCT(sourceFile, bctFile);
    
    fprintf('\n✅ Conversion completed successfully!\n');
    fprintf('Enhanced BCT file created: %s\n', bctFile);
    
    % Quick verification
    fprintf('\nQuick verification:\n');
    B = bct.bct.open(bctFile);
    fprintf('- BCT dimensions: T=%d, N=%d, fs=%d Hz\n', B.T, B.N, B.fs);
    fprintf('- Has preprocessed signals: %s\n', B.has('/signals/preproc'));
    fprintf('- Has node descriptors: %s\n', B.has('/node_info/channel_name'));
    fprintf('- Has feature metadata: %s\n', B.has('/features/metadata'));
    clear B;
    
catch ME
    fprintf('\n❌ Error during conversion:\n');
    fprintf('Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
    rethrow(ME);
end

fprintf('\nConversion pipeline completed!\n');