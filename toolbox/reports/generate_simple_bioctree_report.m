function generate_simple_bioctree_report(varargin)
% GENERATE_SIMPLE_BIOCTREE_REPORT Create a simple PDF report with BioctreePlotter analysis
%
% Usage:
%   generate_simple_bioctree_report('DataFile', 'path/to/data.h5', 'SignalName', 'signal_name')

% Parse input parameters
p = inputParser;
addParameter(p, 'DataFile', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'SignalName', 'signal_patch_15_pct', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputFile', 'simple_bioctree_report', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

% Check if Report Generator is available
try
    import mlreportgen.report.*
    import mlreportgen.dom.*
    fprintf('✓ Report Generator toolbox available\n');
catch ME
    error('BioctreeReport:MissingToolbox', 'MATLAB Report Generator toolbox is required.');
end

% Validate data file
data_file = p.Results.DataFile;
if ~exist(data_file, 'file')
    error('BioctreeReport:FileNotFound', 'Data file not found: %s', data_file);
end

fprintf('Generating report for: %s\n', data_file);
fprintf('Signal: %s\n', p.Results.SignalName);

%% Create Report
report_file = fullfile(pwd, 'reports', sprintf('%s.pdf', p.Results.OutputFile));

try
    % Create report object
    rpt = Report(report_file, 'pdf');
    
    fprintf('Creating report: %s\n', report_file);
    
    % Title page
    titlepg = TitlePage();
    titlepg.Title = 'Bioctree Graph Signal Analysis';
    titlepg.Subtitle = sprintf('Analysis of %s signal', p.Results.SignalName);
    titlepg.Author = sprintf('Generated on %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    [~, filename, ~] = fileparts(data_file);
    titlepg.Publisher = sprintf('Data source: %s', filename);
    rpt.add(titlepg);
    
    % Analysis section
    analysis_section = Chapter('Title', 'Signal Analysis Results');
    
    % Load plotter and get basic info
    plotter = BioctreePlotter(data_file);
    graph_info = plotter.getGraphInfo();
    
    % Add summary text
    summary_text = ['This report presents a comprehensive analysis of graph signal data. ' ...
        'The analysis combines spatial signal distribution visualization with ' ...
        'Graph Fourier Transform spectral analysis.'];
    summary_para = Paragraph(summary_text);
    analysis_section.add(summary_para);
    
    % Add data summary
    data_text = sprintf(['Data Summary:\n' ...
        '• Data File: %s\n' ...
        '• Number of Vertices: %d\n' ...
        '• Number of Edges: %d\n' ...
        '• Signal Analyzed: %s\n' ...
        '• Analysis Date: %s'], ...
        filename, graph_info.num_vertices, graph_info.num_edges, ...
        p.Results.SignalName, datestr(now, 'yyyy-mm-dd'));
    
    data_para = Paragraph(data_text);
    analysis_section.add(data_para);
    
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
    
    fprintf('✓ Figure generated\n');
    
    % Add figure to report using proper Figure reporter
    fig_reporter = Figure(fig);
    fig_reporter.Snapshot.Caption = sprintf('Analysis of %s signal', p.Results.SignalName);
    fig_reporter.Snapshot.Width = '6.5in';
    fig_reporter.Snapshot.Height = '3in';
    fig_reporter.Scaling = 'custom';
    
    analysis_section.add(fig_reporter);
    
    % Close the figure
    close(fig);
    
    % Add interpretation
    interp_text = ['The surface signal visualization reveals spatial patterns in the data, ' ...
        'while the GFT spectrum shows how signal energy is distributed across ' ...
        'graph frequencies. Low frequencies capture smooth, global variations, ' ...
        'while high frequencies represent localized signal features.'];
    interp_para = Paragraph(interp_text);
    analysis_section.add(interp_para);
    
    % Add section to report
    rpt.add(analysis_section);
    
    % Generate and close report
    rpt.close();
    
    fprintf('✓ Report generated successfully: %s\n', report_file);
    
    % Try to open the report
    try
        if ispc
            winopen(report_file);
        end
    catch
        fprintf('Report saved at: %s\n', report_file);
    end
    
catch ME
    fprintf('✗ Report generation failed: %s\n', ME.message);
    rethrow(ME);
end

end