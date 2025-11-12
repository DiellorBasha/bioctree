%% Simple H5 to BCT Test
clear; clc;

% Add bioctree to path
addpath(genpath('.'));

% File paths
sourceFile = 'data/bioctree_files/raw/sub-0002.h5';
bctFile = 'data/bioctree_files/processed/sub-0002_simple.bct.h5';

% Run simple conversion
fprintf('Running simple H5 to BCT conversion...\n');

try
    loadH5ToBCTSimple(sourceFile, bctFile);
    fprintf('\n✅ Simple conversion completed!\n');
    
catch ME
    fprintf('\n❌ Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end