% Debug signal import issue
bioctree_start

% Create BCT object
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.graph.Import.fromFreeSurfer(path);
fprintf('Created BCT object with N=%d vertices\n', B.N);

% Try to add a simple signal
try
    test_signal = rand(B.N, 1);
    B.addSignal(test_signal, 'test_signal');
    fprintf('Successfully added test signal\n');
    
    % Check signals
    signals = B.signals;
    fprintf('Available signals: %d\n', length(fieldnames(signals)));
    
catch ME
    fprintf('Error adding signal: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Error occurred at: %s\n', ME.stack(1).name);
        fprintf('Line: %d\n', ME.stack(1).line);
    end
end

% Now try the FreeSurfer curvature import
try
    curv_path = 'test-data\freesurfer\fsaverage\surf\lh.curv';
    B = bct.io.signal.Import.fromFreeSurfer(curv_path, B);
    fprintf('Successfully imported FreeSurfer curvature signal\n');
    
    signals = B.signals;
    fprintf('Available signals: %d\n', length(fieldnames(signals)));
    disp(signals);
catch ME
    fprintf('Error importing FreeSurfer signal: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Error occurred at: %s\n', ME.stack(1).name);
        fprintf('Line: %d\n', ME.stack(1).line);
    end
end
