function data = db_load_test_bct(varargin)
% DB_LOAD_TEST_BCT Load the standard test BCT file for bioctree development
%
% ⚠️  DEPRECATED: This function is deprecated and will be removed in a future version.
% Use the BCT class system instead: obj = bct.open('test_bioctree_standard.h5')
%
% This function loads the canonical test BCT file created by db_create_test_bct().
% If the file doesn't exist, it will be created automatically.
%
% Usage:
%   data = db_load_test_bct()
%   data = db_load_test_bct('param', value, ...)
%
% Parameters:
%   'FilePath'      - Path to test BCT file (.h5 extension, default: auto-detected)
%   'DataType'      - 'all', 'graph', 'signal', 'metadata' (default: 'all')
%   'CreateIfMissing' - Create test file if it doesn't exist (default: true)
%   'Verbose'       - Display loading information (default: false)
%
% Outputs:
%   data - Structure containing requested data from test BCT file
%
% Examples:
%   % Load complete test dataset
%   data = db_load_test_bct();
%
%   % Load only graph structure  
%   G = db_load_test_bct('DataType', 'graph');
%
%   % Load with verbose output
%   data = db_load_test_bct('Verbose', true);
%
% See also: DB_CREATE_TEST_BCT, INBCT

%% Parse Inputs
p = inputParser;
addParameter(p, 'FilePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'DataType', 'all', @(x) ismember(lower(x), {'all', 'graph', 'signal', 'metadata'}));
addParameter(p, 'CreateIfMissing', true, @islogical);
addParameter(p, 'Verbose', false, @islogical);
parse(p, varargin{:});

file_path = p.Results.FilePath;
data_type = lower(p.Results.DataType);
create_if_missing = p.Results.CreateIfMissing;
verbose = p.Results.Verbose;

% Issue deprecation warning
warning('bioctree:DeprecatedFunction', ...
    'db_load_test_bct is deprecated. Use BCT class: obj = bct.open(''test_bioctree_standard.h5'')');

%% Determine File Path
if isempty(file_path)
    % Try to use bioctree_config first
    try
        config = bioctree_config();
        file_path = fullfile(config.DataPath, 'test_bioctree_standard.h5');
    catch
        % Fall back to current directory
        file_path = 'test_bioctree_standard.h5';
        if verbose
            fprintf('⚠ Could not load bioctree_config, using current directory\n');
        end
    end
end

%% Check if File Exists
if ~exist(file_path, 'file')
    if create_if_missing
        if verbose
            fprintf('Standard test BCT file not found. Creating...\n');
        end
        
        success = db_create_test_bct(file_path, 'Verbose', verbose);
        
        if ~success
            error('db_load_test_bct:CreationFailed', ...
                'Failed to create standard test BCT file: %s', file_path);
        end
        
        if verbose
            fprintf('✓ Standard test BCT file created\n');
        end
    else
        error('db_load_test_bct:FileNotFound', ...
            'Standard test BCT file not found: %s\nUse ''CreateIfMissing'', true to create it.', ...
            file_path);
    end
end

%% Load Data
if verbose
    fprintf('Loading standard test BCT file: %s\n', file_path);
end

try
    switch data_type
        case 'all'
            data = inbct(file_path, 'Verbose', verbose);
            
        case 'graph'
            data = inbct(file_path, 'DataType', 'graph', 'Verbose', verbose);
            
        case 'signal'
            data = inbct(file_path, 'DataType', 'signal', 'Verbose', verbose);
            
        case 'metadata'
            data = inbct(file_path, 'DataType', 'metadata', 'Verbose', verbose);
    end
    
    if verbose
        if isstruct(data) && isfield(data, 'graph') && isfield(data.graph, 'N')
            fprintf('✓ Loaded test dataset: %d vertices', data.graph.N);
            if isfield(data, 'X') && ~isempty(data.X)
                fprintf(', signal size [%d x %d]', size(data.X, 1), size(data.X, 2));
            end
            fprintf('\n');
        else
            fprintf('✓ Test data loaded successfully\n');
        end
    end
    
catch ME
    error('db_load_test_bct:LoadError', ...
        'Failed to load test BCT file: %s\nError: %s', file_path, ME.message);
end

end