%% Test TailwindConsole Component
% Quick test script for the console component

clear; clc;
bioctree_start

%% Create figure and console

fig = uifigure('Name', 'Console Test', 'Position', [100 100 800 400]);
console = TailwindConsole(fig, [0 0 800 400]);

% Test it
console.info('BCT Toolbox initialized');
console.success('Operation completed!');
console.warning('High memory usage');
console.error('Failed to load file');
%% Add various message types
messages = {
    struct('level', 'info', 'text', 'BCT Toolbox initialized')
    struct('level', 'success', 'text', 'Mesh loaded successfully: 12,345 vertices')
    struct('level', 'warning', 'text', 'High frequency content detected')
    struct('level', 'error', 'text', 'Failed to compute eigenbasis: matrix singular')
    struct('level', 'info', 'text', 'Computing Laplace-Beltrami operator...')
    struct('level', 'success', 'text', 'Eigendecomposition complete in 2.3s')
    struct('level', 'info', 'text', 'Applying spatial filter...')
    struct('level', 'warning', 'text', 'Filter order reduced for stability')
    struct('level', 'success', 'text', 'Signal filtered successfully')
};

for i = 1:length(messages)
    console.send(struct('cmd', 'addMessage', 'message', messages{i}));
    pause(0.3);
end

%% Test filtering
disp('Testing filter levels...');
pause(1);

levels = {'all', 'error', 'warning', 'success', 'info', 'all'};
for i = 1:length(levels)
    pause(1.5);
    console.send(struct('cmd', 'setFilter', 'filter', levels{i}));
    fprintf('Filter: %s\n', levels{i});
end

%% Test clear
pause(1);
console.send(struct('cmd', 'clear'));
disp('Console cleared');

pause(0.5);
console.send(struct('cmd', 'addMessage', ...
    'message', struct('level', 'info', 'text', 'Console test complete!')));

disp('Console test complete!');
