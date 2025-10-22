function generate_bioctree_analysis_report(varargin)
% GENERATE_BIOCTREE_ANALYSIS_REPORT Create professional report with BioctreePlotter analysis
%
% This function generates a comprehensive report showing surface signal visualization
% alongside Graph Fourier Transform analysis using MATLAB's Report Generator.
%
% Usage:
%   generate_bioctree_analysis_report()
%   generate_bioctree_analysis_report('param', value, ...)
%
% Parameters:
%   'DataFile'     - HDF5 data file path (default: auto-detect from workflows)
%   'SignalName'   - Signal to analyze (default: 'signal_patch_15_pct')
%   'ReportTitle'  - Report title (default: 'Bioctree Graph Signal Analysis')
%   'OutputFile'   - Output report filename (default: 'bioctree_analysis_report')
%   'Format'       - Report format: 'pdf', 'docx', 'html' (default: 'pdf')
%   'OpenReport'   - Open report after generation (default: true)
%
% Example:
%   generate_bioctree_analysis_report('SignalName', 'signal_patch_15_pct', 'Format', 'pdf');
%
% Dependencies:
%   - MATLAB Report Generator Toolbox
%   - BioctreePlotter class
%   - Valid HDF5 data file with graph and signal data

% Parse input parameters
p = inputParser;
addParameter(p, 'DataFile', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'SignalName', 'signal_patch_15_pct', @(x) ischar(x) || isstring(x));
addParameter(p, 'ReportTitle', 'Bioctree Graph Signal Analysis', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputFile', 'bioctree_analysis_report', @(x) ischar(x) || isstring(x));
addParameter(p, 'Format', 'pdf', @(x) any(validatestring(x, {'pdf', 'docx', 'html'})));
addParameter(p, 'OpenReport', true, @islogical);
parse(p, varargin{:});

% Check if Report Generator is available
try
    import mlreportgen.report.*
    import mlreportgen.dom.*
    fprintf('✓ Report Generator toolbox available\n');
catch ME
    error('BioctreeReport:MissingToolbox', ...
        'MATLAB Report Generator toolbox is required. Error: %s', ME.message);
end

% Auto-detect data file if not provided
if isempty(p.Results.DataFile)
    data_file = auto_detect_data_file();
    if isempty(data_file)
        error('BioctreeReport:NoDataFile', ...
            'No data file specified and could not auto-detect. Please provide DataFile parameter.');
    end
else
    data_file = p.Results.DataFile;
end

% Validate data file exists
if ~exist(data_file, 'file')
    error('BioctreeReport:FileNotFound', 'Data file not found: %s', data_file);
end

fprintf('Generating report for: %s\n', data_file);
fprintf('Signal: %s\n', p.Results.SignalName);

%% Create Report
report_file = fullfile(pwd, 'reports', sprintf('%s.%s', p.Results.OutputFile, p.Results.Format));

try
    % Create report object
    switch p.Results.Format
        case 'pdf'
            rpt = Report(report_file, 'pdf');
        case 'docx'
            rpt = Report(report_file, 'docx');
        case 'html'
            rpt = Report(report_file, 'html');
    end
    
    fprintf('Creating report: %s\n', report_file);
    
    %% Title Page
    titlepg = TitlePage();
    titlepg.Title = p.Results.ReportTitle;
    titlepg.Subtitle = sprintf('Analysis of %s signal', p.Results.SignalName);
    titlepg.Author = sprintf('Generated on %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    [~, filename, ~] = fileparts(data_file);
    titlepg.Publisher = sprintf('Data source: %s', filename);
    add(rpt, titlepg);
    
    %% Table of Contents
    add(rpt, TableOfContents);
    
    %% Executive Summary Section
    exec_section = Section('Title', 'Executive Summary');
    
    % Load plotter to get basic info
    plotter = BioctreePlotter(data_file);
    graph_info = plotter.getGraphInfo();
    
    summary_text = Paragraph(['This report presents a comprehensive analysis of graph signal data using ' ...
        'the BioctreePlotter visualization framework. The analysis focuses on spatial signal distribution ' ...
        'and spectral characteristics through Graph Fourier Transform (GFT) analysis.']);
    add(exec_section, summary_text);
    
    % Data overview as formatted text
    data_summary = Paragraph([...
        'Data File: ', filename, newline, ...
        'Number of Vertices: ', sprintf('%d', graph_info.num_vertices), newline, ...
        'Number of Edges: ', sprintf('%d', graph_info.num_edges), newline, ...
        'Signal Analyzed: ', p.Results.SignalName, newline, ...
        'Analysis Date: ', datestr(now, 'yyyy-mm-dd')]);
    
    add(exec_section, data_summary);
    add(rpt, exec_section);
    
    %% Analysis Results Section
    results_section = Section('Title', 'Analysis Results');
    
    results_intro = Paragraph(['The following analysis presents two complementary views of the graph signal data: ' ...
        '(1) spatial distribution mapped onto the surface mesh, and (2) spectral energy distribution ' ...
        'obtained through Graph Fourier Transform analysis.']);
    add(results_section, results_intro);
    
    %% Generate the multipanel figure
    fprintf('Generating multipanel analysis figure...\n');
    
    % Create plot specifications for 2-panel layout
    plot_specs = {
        struct('type', 'surfaceSignal', 'subplot', [1,2,1], ...
               'title', 'Surface Signal Distribution', ...
               'params', {{'SignalName', p.Results.SignalName, 'ShowInfo', false}}), ...
        struct('type', 'gft', 'subplot', [1,2,2], ...
               'title', 'Graph Fourier Transform Spectrum', ...
               'params', {{'SignalName', p.Results.SignalName, 'ShowInfo', false}})
    };
    
    % Generate the multipanel figure
    fig = plotter.plotMultipanel(plot_specs, ...
        'FigureSize', [1200, 500], ...
        'MainTitle', sprintf('Signal Analysis: %s', p.Results.SignalName), ...
        'ShowInfo', false);
    
    % Save figure as high-resolution image
    fig_path = fullfile(pwd, 'reports', 'temp_analysis_figure.png');
    print(fig, fig_path, '-dpng', '-r300');
    close(fig);
    
    fprintf('✓ Figure saved: %s\n', fig_path);
    
    %% Add figure to report
    fig_para = Paragraph();
    fig_image = Image(fig_path);
    fig_image.Style = {Width('100%'), HAlign('center')};
    add(fig_para, fig_image);
    add(results_section, fig_para);
    
    % Figure caption
    fig_caption = Paragraph(['Figure 1: Comprehensive analysis of ', p.Results.SignalName, ...
        '. Left panel shows the spatial distribution of signal values mapped onto the surface mesh. ' ...
        'Right panel displays the spectral energy distribution obtained from Graph Fourier Transform analysis, ' ...
        'with low-frequency components highlighted in red.']);
    add(results_section, fig_caption);
    
    add(rpt, results_section);
    
    %% Interpretation Section
    interp_section = Section('Title', 'Results Interpretation');
    
    % Get some basic signal statistics for interpretation
    signal_data = plotter.loadSignalData(p.Results.SignalName, 1);
    signal_stats = struct();
    signal_stats.min_val = min(signal_data);
    signal_stats.max_val = max(signal_data);
    signal_stats.mean_val = mean(signal_data);
    signal_stats.std_val = std(signal_data);
    signal_stats.nonzero_count = sum(signal_data ~= 0);
    signal_stats.nonzero_pct = 100 * signal_stats.nonzero_count / length(signal_data);
    
    % Signal statistics subsection
    stats_subsection = Section('Title', 'Signal Statistics');
    
    stats_list = UnorderedList();
    add(stats_list, {
        sprintf('Signal range: [%.3f, %.3f]', signal_stats.min_val, signal_stats.max_val);
        sprintf('Mean amplitude: %.3f ± %.3f (std)', signal_stats.mean_val, signal_stats.std_val);
        sprintf('Active vertices: %d / %d (%.1f%%)', signal_stats.nonzero_count, length(signal_data), signal_stats.nonzero_pct);
    });
    add(stats_subsection, stats_list);
    add(interp_section, stats_subsection);
    
    % Spatial analysis subsection
    spatial_subsection = Section('Title', 'Spatial Analysis');
    spatial_text = Paragraph(['The surface signal visualization (left panel) reveals the spatial distribution ' ...
        'of signal amplitudes across the graph vertices. This view helps identify spatial patterns, ' ...
        'localized activations, and regions of signal concentration or absence.']);
    add(spatial_subsection, spatial_text);
    add(interp_section, spatial_subsection);
    
    % Spectral analysis subsection
    spectral_subsection = Section('Title', 'Spectral Analysis');
    spectral_text = Paragraph(['The Graph Fourier Transform spectrum (right panel) decomposes the signal ' ...
        'into frequency components defined by the graph structure. Low-frequency components (highlighted in red) ' ...
        'represent smooth variations across connected vertices, while high-frequency components capture ' ...
        'localized or rapidly varying signal features.']);
    add(spectral_subsection, spectral_text);
    add(interp_section, spectral_subsection);
    
    add(rpt, interp_section);
    
    %% Technical Details Section
    tech_section = Section('Title', 'Technical Details');
    
    tech_text = Paragraph(['This analysis was generated using the BioctreePlotter MATLAB framework, ' ...
        'which provides specialized visualization tools for HDF5-stored graph data. The Graph Fourier Transform ' ...
        'analysis utilizes the GSPBox library for efficient computation of graph spectral properties.']);
    add(tech_section, tech_text);
    
    % Method details
    method_subsection = Section('Title', 'Analysis Methods');
    method_list = OrderedList();
    add(method_list, {
        'Load graph structure and signal data from HDF5 file';
        'Compute or load graph Laplacian eigendecomposition';
        'Apply Graph Fourier Transform to signal data';
        'Generate surface mesh visualization with signal coloring';
        'Create spectral energy plot with frequency highlighting';
        'Combine visualizations into comprehensive analysis view';
    });
    add(method_subsection, method_list);
    add(tech_section, method_subsection);
    
    add(rpt, tech_section);
    
    %% Generate and close report
    close(rpt);
    
    % Clean up temporary figure file
    if exist(fig_path, 'file')
        delete(fig_path);
    end
    
    fprintf('✓ Report generated successfully: %s\n', report_file);
    
    % Open report if requested
    if p.Results.OpenReport
        try
            if ispc
                system(sprintf('start "%s"', report_file));
            elseif ismac
                system(sprintf('open "%s"', report_file));
            else
                system(sprintf('xdg-open "%s"', report_file));
            end
            fprintf('✓ Report opened\n');
        catch
            fprintf('⚠ Could not automatically open report. File saved at: %s\n', report_file);
        end
    end
    
catch ME
    fprintf('✗ Report generation failed: %s\n', ME.message);
    
    % Clean up on error
    if exist('fig_path', 'var') && exist(fig_path, 'file')
        delete(fig_path);
    end
    
    rethrow(ME);
end

end

function data_file = auto_detect_data_file()
% AUTO_DETECT_DATA_FILE Try to find a suitable HDF5 data file
%
% Returns:
%   data_file - Path to detected data file, or empty string if none found

data_file = '';

% Check for common data file locations
search_paths = {
    'workflows/test_ico_graph.h5';
    'data/test_ico_graph.h5';
    'test-data/test_ico_graph.h5';
};

for i = 1:length(search_paths)
    if exist(search_paths{i}, 'file')
        data_file = search_paths{i};
        fprintf('Auto-detected data file: %s\n', data_file);
        return;
    end
end

% If no file found, check if we're in workflows directory and look for recent .h5 files
if contains(pwd, 'workflows')
    h5_files = dir('*.h5');
    if ~isempty(h5_files)
        % Get most recent file
        [~, idx] = max([h5_files.datenum]);
        data_file = h5_files(idx).name;
        fprintf('Auto-detected recent H5 file: %s\n', data_file);
        return;
    end
end

fprintf('No suitable data file auto-detected\n');
end