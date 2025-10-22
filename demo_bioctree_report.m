%% DEMO_BIOCTREE_REPORT - Demonstrate BioctreePlotter report generation
%
% This script demonstrates how to create professional PDF reports using
% MATLAB's Report Generator with BioctreePlotter multipanel analysis.
%
% The report includes:
%   - Title page with analysis summary
%   - 2-panel figure: Surface Signal + Graph Fourier Transform
%   - Data statistics and interpretation
%   - Professional formatting suitable for documentation
%
% Requirements:
%   - MATLAB Report Generator Toolbox
%   - BioctreePlotter class
%   - Valid HDF5 data file

clear; clc;
fprintf('=== BioctreePlotter Report Generation Demo ===\n\n');

% Initialize bioctree system
bioctree_start;
addpath('reports');

%% Check for Report Generator availability
try
    import mlreportgen.report.*
    import mlreportgen.dom.*
    fprintf('✓ Report Generator toolbox available\n');
catch ME
    fprintf('✗ Report Generator toolbox not available: %s\n', ME.message);
    fprintf('Please install MATLAB Report Generator toolbox to run this demo.\n');
    return;
end

%% Use existing test data
data_file = 'C:\CodingProjects\data\bioctree_files\icosphere_patch_demo.h5';

if ~exist(data_file, 'file')
    fprintf('✗ Test data file not found: %s\n', data_file);
    fprintf('Please run workflow_sphere first to generate test data.\n');
    return;
else
    fprintf('✓ Using test data: %s\n', data_file);
end

%% Generate report with different signals
signals_to_analyze = {'signal_patch_15_pct', 'signal_patch_25_pct'};

for i = 1:length(signals_to_analyze)
    signal_name = signals_to_analyze{i};
    
    fprintf('\n%d. Generating report for signal: %s\n', i, signal_name);
    
    try
        % Generate report
        output_name = sprintf('bioctree_report_%s', signal_name);
        
        generate_simple_bioctree_report(...
            'DataFile', data_file, ...
            'SignalName', signal_name, ...
            'OutputFile', output_name);
        
        fprintf('   ✓ Report generated: %s.pdf\n', output_name);
        
    catch ME
        fprintf('   ✗ Report generation failed: %s\n', ME.message);
    end
end

%% Report Summary
fprintf('\n=== Generated Reports Summary ===\n');

% List all generated PDF reports
reports_dir = 'reports';
pdf_files = dir(fullfile(reports_dir, '*.pdf'));

if ~isempty(pdf_files)
    fprintf('Generated PDF reports in %s/:\n', reports_dir);
    total_size = 0;
    
    for i = 1:length(pdf_files)
        size_kb = pdf_files(i).bytes / 1024;
        total_size = total_size + size_kb;
        
        fprintf('  %d. %s (%.1f KB) - %s\n', ...
            i, pdf_files(i).name, size_kb, ...
            datestr(pdf_files(i).datenum, 'yyyy-mm-dd HH:MM:SS'));
    end
    
    fprintf('\nTotal: %d files, %.1f KB\n', length(pdf_files), total_size);
    
    % Open the most recent report
    if length(pdf_files) >= 1
        latest_file = fullfile(reports_dir, pdf_files(end).name);
        fprintf('\n✓ Opening latest report: %s\n', pdf_files(end).name);
        
        try
            if ispc
                winopen(latest_file);
            end
        catch
            fprintf('   Report saved at: %s\n', latest_file);
        end
    end
    
else
    fprintf('No PDF reports found in %s/\n', reports_dir);
end

%% Feature demonstration
fprintf('\n=== Report Features Demonstrated ===\n');
fprintf('✓ Professional title page with metadata\n');
fprintf('✓ 2-panel multipanel analysis (Surface Signal + GFT)\n');
fprintf('✓ High-resolution figure embedding (300 DPI)\n');
fprintf('✓ Data summary and statistics\n');
fprintf('✓ Technical interpretation and analysis\n');
fprintf('✓ Automatic PDF generation and opening\n');

fprintf('\n=== Usage Examples ===\n');
fprintf('Basic usage:\n');
fprintf('  generate_simple_bioctree_report(''DataFile'', ''data.h5'', ''SignalName'', ''my_signal'');\n\n');

fprintf('Custom output:\n');
fprintf('  generate_simple_bioctree_report(''DataFile'', ''data.h5'', ...\n');
fprintf('                                  ''SignalName'', ''signal_patch_15_pct'', ...\n');
fprintf('                                  ''OutputFile'', ''my_analysis_report'');\n\n');

fprintf('✓ Demo completed successfully!\n');