%% DEMO_REPORT_GENERATION - Demonstrate BioctreePlotter report generation
%
% This script demonstrates how to generate professional reports using
% MATLAB's Report Generator with BioctreePlotter analysis.
%
% Requirements:
%   - MATLAB Report Generator Toolbox
%   - BioctreePlotter class
%   - Valid HDF5 data file (will auto-detect or use workflows data)

%% Initialize
clear; clc;
fprintf('=== BioctreePlotter Report Generation Demo ===\n\n');

% Add paths
bioctree_start;

%% Check for Report Generator availability
try
    import mlreportgen.report.*
    import mlreportgen.dom.*
    fprintf('✓ Report Generator toolbox is available\n');
catch ME
    fprintf('✗ Report Generator toolbox not available: %s\n', ME.message);
    fprintf('Please install MATLAB Report Generator toolbox to run this demo.\n');
    return;
end

%% Generate test data if needed
fprintf('\n1. Setting up test data...\n');

% Check if we have test data available
test_data_file = 'workflows/test_ico_graph.h5';

if ~exist(test_data_file, 'file')
    fprintf('   Creating test icosphere data...\n');
    
    % Change to workflows directory and create test data
    original_dir = pwd;
    cd('workflows');
    
    try
        % Run workflow to generate test data
        workflow_sphere;
        fprintf('   ✓ Test data created\n');
        
        % Return to original directory
        cd(original_dir);
        
    catch ME
        cd(original_dir);
        fprintf('   ✗ Failed to create test data: %s\n', ME.message);
        return;
    end
else
    fprintf('   ✓ Test data already available: %s\n', test_data_file);
end

%% Generate PDF Report
fprintf('\n2. Generating PDF report...\n');

try
    generate_bioctree_analysis_report(...
        'DataFile', test_data_file, ...
        'SignalName', 'signal_patch_15_pct', ...
        'ReportTitle', 'Bioctree Graph Signal Analysis Report', ...
        'OutputFile', 'demo_analysis_report', ...
        'Format', 'pdf', ...
        'OpenReport', true);
    
    fprintf('✓ PDF report generated successfully!\n');
    
catch ME
    fprintf('✗ PDF report generation failed: %s\n', ME.message);
end

%% Generate HTML Report (alternative format)
fprintf('\n3. Generating HTML report (alternative format)...\n');

try
    generate_bioctree_analysis_report(...
        'DataFile', test_data_file, ...
        'SignalName', 'signal_patch_15_pct', ...
        'ReportTitle', 'Bioctree Graph Signal Analysis Report (HTML)', ...
        'OutputFile', 'demo_analysis_report_html', ...
        'Format', 'html', ...
        'OpenReport', false);  % Don't auto-open HTML to avoid multiple windows
    
    fprintf('✓ HTML report generated successfully!\n');
    
catch ME
    fprintf('✗ HTML report generation failed: %s\n', ME.message);
end

%% Report Generation Summary
fprintf('\n=== Report Generation Summary ===\n');
fprintf('Reports saved in: %s\n', fullfile(pwd, 'reports'));

% List generated reports
reports_dir = fullfile(pwd, 'reports');
if exist(reports_dir, 'dir')
    report_files = dir(fullfile(reports_dir, 'demo_analysis_report*'));
    
    if ~isempty(report_files)
        fprintf('Generated files:\n');
        for i = 1:length(report_files)
            fprintf('  - %s (%.1f KB)\n', report_files(i).name, report_files(i).bytes/1024);
        end
    else
        fprintf('No report files found in reports directory.\n');
    end
else
    fprintf('Reports directory not found.\n');
end

fprintf('\n✓ Demo completed!\n');

%% Usage Examples
fprintf('\n=== Additional Usage Examples ===\n');
fprintf('Example 1: Custom signal analysis\n');
fprintf('  generate_bioctree_analysis_report(''SignalName'', ''my_signal'', ''Format'', ''docx'');\n\n');

fprintf('Example 2: Specific data file\n');
fprintf('  generate_bioctree_analysis_report(''DataFile'', ''path/to/data.h5'', ''Format'', ''pdf'');\n\n');

fprintf('Example 3: Custom report title\n');
fprintf('  generate_bioctree_analysis_report(''ReportTitle'', ''My Analysis'', ''OutputFile'', ''my_report'');\n\n');