function demoSpatioTemporalPatterns(G, varargin)
% DEMOSPATIOTEMPORALPATTERNS Demonstrate various spatiotemporal pattern generators
%
% Usage:
%   demoSpatioTemporalPatterns(G)
%   demoSpatioTemporalPatterns(G, 'param', value, ...)
%
% Inputs:
%   G - Graph structure with at least G.N (number of vertices)
%       Recommended: G.coords for spatial visualization
%       Optional: G.jtv with G.jtv.T and G.jtv.fs for temporal patterns
%
% Parameters:
%   'patterns'      - Cell array of pattern types to demonstrate
%                     Default: {'patch', 'wave', 'ripple', 'oscillation', 'burst'}
%   'showPlots'     - Whether to create visualization plots (default: true)
%   'saveResults'   - Whether to save generated signals (default: false)
%   'outputDir'     - Directory for saved results (default: current directory)
%
% Examples:
%   % Basic demo with all patterns
%   demoSpatioTemporalPatterns(G);
%
%   % Demo specific patterns only
%   demoSpatioTemporalPatterns(G, 'patterns', {'patch', 'wave'});
%
%   % Demo without plots (for batch processing)
%   demoSpatioTemporalPatterns(G, 'showPlots', false, 'saveResults', true);

% Parse inputs
p = inputParser;
addRequired(p, 'G');
addParameter(p, 'patterns', {'patch', 'wave', 'ripple', 'oscillation', 'burst'}, @iscell);
addParameter(p, 'showPlots', true, @islogical);
addParameter(p, 'saveResults', false, @islogical);
addParameter(p, 'outputDir', '.', @ischar);
parse(p, G, varargin{:});

patterns = p.Results.patterns;
show_plots = p.Results.showPlots;
save_results = p.Results.saveResults;
output_dir = p.Results.outputDir;

fprintf('=== Spatiotemporal Pattern Generation Demo ===\n');
fprintf('Graph: %d vertices, %d edges\n', G.N, nnz(G.W)/2);

if isfield(G, 'jtv')
    fprintf('Temporal: %d time steps, %.2f Hz sampling\n', G.jtv.T, G.jtv.fs);
else
    fprintf('Static patterns only (no temporal dimension)\n');
end

% Initialize results storage
results = struct();

% Generate and visualize each pattern type
for i = 1:length(patterns)
    pattern_type = patterns{i};
    fprintf('\n--- Generating %s pattern ---\n', pattern_type);
    
    try
        % Generate pattern with default parameters
        switch lower(pattern_type)
            case 'patch'
                [signal, params] = generatePatchSignal(G, 'patchSize', 0.15, 'growthMode', 'grow');
            case 'wave'
                [signal, params] = generateSpatioTemporalPattern(G, 'wave', 'waveSpeed', 2, 'frequency', 0.5);
            case 'ripple'
                [signal, params] = generateSpatioTemporalPattern(G, 'ripple', 'waveSpeed', 1.5, 'frequency', 1);
            case 'oscillation'
                [signal, params] = generateSpatioTemporalPattern(G, 'oscillation', 'frequency', 2);
            case 'burst'
                [signal, params] = generateSpatioTemporalPattern(G, 'burst', 'frequency', 3);
            case 'gradient'
                [signal, params] = generateSpatioTemporalPattern(G, 'gradient', 'frequency', 0.5);
            case 'noise'
                [signal, params] = generateSpatioTemporalPattern(G, 'noise', 'noiseType', 'colored', 'correlation', 0.3);
            otherwise
                [signal, params] = generateSpatioTemporalPattern(G, pattern_type);
        end
        
        % Store results
        results.(pattern_type).signal = signal;
        results.(pattern_type).params = params;
        
        % Print basic statistics
        fprintf('  Signal range: [%.3f, %.3f]\n', min(signal(:)), max(signal(:)));
        fprintf('  Signal energy: %.3f\n', norm(signal(:))^2);
        
        if show_plots
            visualizePattern(G, signal, params, pattern_type);
        end
        
        if save_results
            filename = fullfile(output_dir, sprintf('pattern_%s.mat', pattern_type));
            save(filename, 'signal', 'params', 'G');
            fprintf('  Saved to: %s\n', filename);
        end
        
    catch ME
        fprintf('  Error generating %s: %s\n', pattern_type, ME.message);
        results.(pattern_type).error = ME.message;
    end
end

% Generate comparison figure if requested
if show_plots && length(patterns) > 1
    createComparisonFigure(G, results, patterns);
end

fprintf('\n=== Demo Complete ===\n');
end

function visualizePattern(G, signal, params, pattern_type)
% Visualize a single pattern

% Determine if temporal or static
is_temporal = size(signal, 2) > 1;

if is_temporal
    % Create temporal visualization
    figure('Name', sprintf('%s Pattern - Temporal', pattern_type), 'Position', [100, 100, 1200, 400]);
    
    % Plot 1: Signal evolution over time (first few nodes)
    subplot(1, 3, 1);
    num_nodes_to_plot = min(10, G.N);
    plot((0:size(signal,2)-1), signal(1:num_nodes_to_plot, :)');
    title(sprintf('%s - Time Evolution', pattern_type));
    xlabel('Time Step');
    ylabel('Signal Amplitude');
    legend(arrayfun(@(x) sprintf('Node %d', x), 1:num_nodes_to_plot, 'UniformOutput', false), 'Location', 'best');
    grid on;
    
    % Plot 2: Spatial snapshot at middle time point
    subplot(1, 3, 2);
    mid_time = round(size(signal, 2) / 2);
    if isfield(G, 'coords') && size(G.coords, 2) >= 2
        scatter(G.coords(:, 1), G.coords(:, 2), 50, signal(:, mid_time), 'filled');
        colorbar;
        title(sprintf('%s - Spatial (t=%d)', pattern_type, mid_time));
        xlabel('X coordinate');
        ylabel('Y coordinate');
    else
        plot(signal(:, mid_time));
        title(sprintf('%s - Spatial (t=%d)', pattern_type, mid_time));
        xlabel('Node Index');
        ylabel('Signal Amplitude');
        grid on;
    end
    
    % Plot 3: Energy over time
    subplot(1, 3, 3);
    energy = sum(signal.^2, 1);
    plot(0:length(energy)-1, energy, 'b-', 'LineWidth', 2);
    title(sprintf('%s - Energy Evolution', pattern_type));
    xlabel('Time Step');
    ylabel('Total Energy');
    grid on;
    
else
    % Create static visualization
    figure('Name', sprintf('%s Pattern - Static', pattern_type), 'Position', [100, 100, 800, 300]);
    
    % Plot 1: Signal values
    subplot(1, 2, 1);
    if isfield(G, 'coords') && size(G.coords, 2) >= 2
        scatter(G.coords(:, 1), G.coords(:, 2), 50, signal(:, 1), 'filled');
        colorbar;
        title(sprintf('%s - Spatial Distribution', pattern_type));
        xlabel('X coordinate');
        ylabel('Y coordinate');
    else
        plot(signal(:, 1), 'b-', 'LineWidth', 1.5);
        title(sprintf('%s - Signal Values', pattern_type));
        xlabel('Node Index');
        ylabel('Signal Amplitude');
        grid on;
    end
    
    % Plot 2: Histogram
    subplot(1, 2, 2);
    histogram(signal(:, 1), 20, 'FaceAlpha', 0.7);
    title(sprintf('%s - Value Distribution', pattern_type));
    xlabel('Signal Amplitude');
    ylabel('Count');
    grid on;
end

% Add parameter information as text
param_text = sprintf('Parameters:\n');
param_fields = fieldnames(params);
for i = 1:min(5, length(param_fields)) % Show first 5 parameters
    field = param_fields{i};
    value = params.(field);
    if isnumeric(value) && length(value) == 1
        param_text = [param_text, sprintf('%s: %.3f\n', field, value)];
    elseif ischar(value) || isstring(value)
        param_text = [param_text, sprintf('%s: %s\n', field, value)];
    end
end

% Add text box with parameters
annotation('textbox', [0.02, 0.02, 0.25, 0.3], 'String', param_text, ...
           'FontSize', 9, 'BackgroundColor', 'white', 'EdgeColor', 'black');
end

function createComparisonFigure(G, results, patterns)
% Create a comparison figure showing all patterns

% Filter out patterns with errors
valid_patterns = {};
valid_results = {};
for i = 1:length(patterns)
    if isfield(results.(patterns{i}), 'signal')
        valid_patterns{end+1} = patterns{i};
        valid_results{end+1} = results.(patterns{i});
    end
end

if isempty(valid_patterns)
    return;
end

num_patterns = length(valid_patterns);
figure('Name', 'Pattern Comparison', 'Position', [50, 50, 1400, 800]);

% Determine grid size
rows = ceil(sqrt(num_patterns));
cols = ceil(num_patterns / rows);

for i = 1:num_patterns
    subplot(rows, cols, i);
    
    signal = valid_results{i}.signal;
    pattern_name = valid_patterns{i};
    
    % Show snapshot (middle time point for temporal signals)
    if size(signal, 2) > 1
        mid_time = round(size(signal, 2) / 2);
        signal_snapshot = signal(:, mid_time);
        title_suffix = sprintf(' (t=%d)', mid_time);
    else
        signal_snapshot = signal(:, 1);
        title_suffix = '';
    end
    
    % Plot based on available coordinates
    if isfield(G, 'coords') && size(G.coords, 2) >= 2
        scatter(G.coords(:, 1), G.coords(:, 2), 30, signal_snapshot, 'filled');
        colorbar;
    else
        plot(signal_snapshot, 'LineWidth', 1.5);
        grid on;
    end
    
    title(sprintf('%s%s', pattern_name, title_suffix));
    
    % Add energy information
    energy = norm(signal_snapshot)^2;
    xlabel(sprintf('Energy: %.2f', energy));
end

sgtitle('Spatiotemporal Pattern Comparison');
end