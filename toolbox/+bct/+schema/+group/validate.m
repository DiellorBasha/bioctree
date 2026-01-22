function [isValid, report] = validate(attrs, varargin)
%VALIDATE Validate group attributes against canonical schema
%
% Syntax:
%   isValid = bct.schema.group.validate(attrs)
%   [isValid, report] = bct.schema.group.validate(attrs)
%   [isValid, report] = bct.schema.group.validate(attrs, 'Strict', true)
%
% Inputs:
%   attrs - Group attributes struct to validate
%
% Name-Value Arguments:
%   Strict - true (default) to throw errors, false to return report
%
% Outputs:
%   isValid - true if attributes are valid, false otherwise
%   report  - Structure with validation results:
%             .passed    - true/false
%             .errors    - Cell array of error messages
%             .warnings  - Cell array of warning messages
%             .timestamp - Validation timestamp
%
% Description:
%   Validates group attributes against the canonical BCT group schema.
%   Checks for:
%     - Required base fields (path, schema, package)
%     - Field types and patterns
%     - Schema version format
%     - Path format for HDF5/Zarr compatibility
%
%   Does NOT validate domain-specific fields - those are validated by
%   domain-specific schemas.
%
% Examples:
%   % Validate with errors
%   attrs = struct('path', '/geometry', 'schema', 'bct.manifold.geometry@1.0.0', ...
%                  'package', 'bct.manifold.geometry');
%   isValid = bct.schema.group.validate(attrs);
%
%   % Validate with report
%   [isValid, report] = bct.schema.group.validate(attrs, 'Strict', false);
%   if ~isValid
%       disp(report.errors);
%   end
%
% See also: bct.schema.group, bct.schema.group.make

p = inputParser;
p.addRequired('attrs');
p.addParameter('Strict', true, @islogical);
p.parse(attrs, varargin{:});

strict = p.Results.Strict;

% Initialize report
report = struct(...
    'passed', false, ...
    'errors', {{}}, ...
    'warnings', {{}}, ...
    'timestamp', datetime('now'));

try
    %% Check basic structure
    if ~isstruct(attrs)
        addError(report, 'Group attributes must be a struct');
        if strict
            error('bct:schema:group:NotStruct', 'Group attributes must be a struct');
        end
        isValid = false;
        return;
    end
    
    %% Get schema spec
    spec = bct.schema.group();
    
    %% Check required fields
    requiredFields = fieldnames(spec.fields);
    requiredFields = requiredFields(structfun(@(f) f.required, spec.fields));
    
    for i = 1:numel(requiredFields)
        fieldName = requiredFields{i};
        if ~isfield(attrs, fieldName)
            msg = sprintf('Required group attribute missing: %s', fieldName);
            addError(report, msg);
            if strict
                error('bct:schema:group:MissingField', msg);
            end
            isValid = false;
            return;
        end
    end
    
    %% Validate each present field
    presentFields = fieldnames(attrs);
    for i = 1:numel(presentFields)
        fieldName = presentFields{i};
        
        % Skip fields not in schema (domain-specific extensions)
        if ~isfield(spec.fields, fieldName)
            continue;
        end
        
        fieldSpec = spec.fields.(fieldName);
        value = attrs.(fieldName);
        
        % Check allowed classes
        if isfield(fieldSpec, 'allowedClasses')
            validClass = any(arrayfun(@(c) isa(value, char(c)), fieldSpec.allowedClasses));
            if ~validClass
                msg = sprintf('Field %s has invalid type %s (expected: %s)', ...
                    fieldName, class(value), strjoin(fieldSpec.allowedClasses, ', '));
                addError(report, msg);
                if strict
                    error('bct:schema:group:InvalidType', msg);
                end
                isValid = false;
                return;
            end
        end
        
        % Check pattern (for strings)
        if isfield(fieldSpec, 'pattern') && (isstring(value) || ischar(value))
            value_str = string(value);
            if ~matches(value_str, fieldSpec.pattern)
                msg = sprintf('Field %s value "%s" does not match required pattern: %s', ...
                    fieldName, value_str, fieldSpec.pattern);
                addError(report, msg);
                if strict
                    error('bct:schema:group:InvalidPattern', msg);
                end
                isValid = false;
                return;
            end
        end
        
        % Run custom validation if present
        if isfield(fieldSpec, 'validate') && isa(fieldSpec.validate, 'function_handle')
            try
                fieldSpec.validate(value);
            catch ME
                msg = sprintf('Validation failed for field %s: %s', fieldName, ME.message);
                addError(report, msg);
                if strict
                    rethrow(ME);
                end
                isValid = false;
                return;
            end
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
