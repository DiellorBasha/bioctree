% Test signal_stack initialization
bioctree_start

% Create BCT object
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.graph.Import.fromFreeSurfer(path);
fprintf('Created BCT object with N=%d vertices\n', B.N);

% Try to access signals property to see what happens
try
    signals = B.signals;
    fprintf('signals property access successful\n');
    fprintf('signals type: %s\n', class(signals));
    if isstruct(signals)
        fprintf('signals fields: %s\n', strjoin(fieldnames(signals), ', '));
    end
catch ME
    fprintf('Error accessing signals: %s\n', ME.message);
end
