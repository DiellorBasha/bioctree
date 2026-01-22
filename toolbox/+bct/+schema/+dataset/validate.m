function [isValid, report] = validate(dataset, varargin)
%VALIDATE Validate dataset structure against canonical schema
%
% Syntax:
%   isValid = bct.schema.dataset.validate(dataset)
%   [isValid, report] = bct.schema.dataset.validate(dataset)
%   [isValid, report] = bct.schema.dataset.validate(dataset, 'Strict', true)
%
% Inputs:
%   dataset - Structure to validate
%
% Name-Value Arguments:
%   Strict - true (default) to throw errors, false to return report
%
% Outputs:
%   isValid - true if dataset is valid, false otherwise
%   report  - Structure with validation results:
%             .passed    - true/false
%             .errors    - Cell array of error messages
%             .warnings  - Cell array of warning messages
%             .timestamp - Validation timestamp
%
% Description:
%   Validates a dataset structure against the canonical BCT dataset schema.
%   Checks for:
%     - Required fields (.value, .attributes)
%     - Field types and values
%     - Attribute compliance with bct.schema.dataset.attributes
%     - Consistency between .value and .attributes.shape
%
% Examples:
%   % Validate with errors
%   isValid = bct.schema.dataset.validate(dataset);
%
%   % Validate with report
%   [isValid, report] = bct.schema.dataset.validate(dataset, 'Strict', false);
%   if ~isValid
%       disp(report.errors);
%   end
%
% See also: bct.schema.dataset, bct.schema.dataset.attributes

p = inputParser;
p.addRequired('dataset');
p.addParameter('Strict', true, @islogical);
p.parse(dataset, varargin{:});

strict = p.Results.Strict;

% Initialize report
report = struct(...
    'passed', false, ...
    'errors', {{}}, ...
    'warnings', {{}}, ...
    'timestamp', datetime('now'));

try
    %% Check basic structure
    if ~isstruct(dataset)
        addError(report, 'Dataset must be a struct');
        if strict
            error('bct:schema:dataset:NotStruct', 'Dataset must be a struct');
        end
        isValid = false;
        return;
    end
    
    %% Check required fields
    if ~isfield(dataset, 'value')
        addError(report, 'Dataset missing required field: .value');
        if strict
            error('bct:schema:dataset:MissingValue', 'Dataset must have .value field');
        end
        isValid = false;
        return;
    end
    
    if ~isfield(dataset, 'attributes')
        addError(report, 'Dataset missing required field: .attributes');
        if strict
            error('bct:schema:dataset:MissingAttributes', 'Dataset must have .attributes field');
        end
        isValid = false;
        return;
    end
    
    %% Validate .value field
    try
        spec = bct.schema.dataset();
        spec.structure.value.validate(dataset.value);
    catch ME
        addError(report, sprintf('Invalid .value field: %s', ME.message));
        if strict
            rethrow(ME);
        end
        isValid = false;
        return;
    end
    
    %% Validate .attributes field
    try
        attrValid = bct.schema.dataset.attributes.validate(dataset.attributes);
        if ~attrValid
            addError(report, 'Invalid .attributes field');
            isValid = false;
            return;
        end
    catch ME
        addError(report, sprintf('Invalid .attributes field: %s', ME.message));
        if strict
            rethrow(ME);
        end
        isValid = false;
        return;
    end
    
    %% Cross-validate value and attributes
    % Check shape consistency
    if isfield(dataset.attributes, 'shape')
        actualShape = size(dataset.value);
        expectedShape = dataset.attributes.shape;
        
        % Compare shapes (handle trailing singleton dimensions)
        if ~isequal(actualShape, expectedShape) && ...
           ~isequal(actualShape, expectedShape(:)')
            msg = sprintf('Shape mismatch: data is [%s] but attributes specify [%s]', ...
                num2str(actualShape), num2str(expectedShape));
            addWarning(report, msg);
        end
    end
    
    % Check dtype consistency
    if isfield(dataset.attributes, 'dtype')
        actualType = class(dataset.value);
        expectedType = char(dataset.attributes.dtype);
        
        if ~strcmp(actualType, expectedType)
            msg = sprintf('Type mismatch: data is %s but attributes specify %s', ...
                actualType, expectedType);
            addWarning(report, msg);
        end
    end
    
    %% Validation passed
    report.passed = true;
    isValid = true;
    
catch ME
    addError(report, sprintf('Validation exception: %s', ME.message));
    if strict
        rethrow(ME);
    end
    isValid = false;
end

end

%% Helper Functions

function addError(report, msg)
    report.errors{end+1} = msg;
    report.passed = false;
end

function addWarning(report, msg)
    report.warnings{end+1} = msg;
end
