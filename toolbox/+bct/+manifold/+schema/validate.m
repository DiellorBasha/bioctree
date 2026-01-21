function [valid, errors] = validate(spec, data, options)
%VALIDATE Validate data against schema specification
%
% Checks whether data conforms to the given schema specification,
% including field presence, types, dimensions, and cross-field constraints.
%
% Syntax:
%   [valid, errors] = bct.manifold.schema.validate(spec, data)
%   [valid, errors] = bct.manifold.schema.validate(spec, data, 'Strict', true)
%
% Inputs:
%   spec  - Schema specification (from bct.manifold.schema.manifold)
%   data  - Structure with fields to validate
%
% Name-Value Arguments:
%   Strict - true (default): error on validation failure
%            false: return validation status without error
%
% Outputs:
%   valid  - Boolean, true if all validations pass
%   errors - Cell array of error messages (empty if valid)
%
% Validation Steps:
%   1. Check required fields are present
%   2. Check field types against allowedClasses
%   3. Check array dimensions (ndims, ncols)
%   4. Check value constraints (finite, positive, in-range)
%   5. Run cross-field validation function
%
% Examples:
%   % Validate and throw error on failure
%   spec = bct.manifold.schema.manifold();
%   bct.manifold.schema.validate(spec, data);
%
%   % Validate and collect errors without throwing
%   [valid, errors] = bct.manifold.schema.validate(spec, data, 'Strict', false);
%   if ~valid
%       disp(errors);
%   end
%
% See also: bct.manifold.schema.manifold, bct.manifold.schema.normalize

arguments
    spec (1,1) struct
    data (1,1) struct
    options.Strict (1,1) logical = true
end

valid = true;
errors = {};

% Handle two-section schema (mesh + meta)
if isfield(spec, 'mesh') && isfield(spec, 'meta')
    % Validate mesh section (required fields)
    [meshValid, meshErrors] = validateSection(spec.mesh, data, 'Mesh');
    if ~meshValid
        valid = false;
        errors = [errors; meshErrors];
    end
    
    % Validate meta section (optional fields)
    [metaValid, metaErrors] = validateSection(spec.meta, data, 'Metadata');
    if ~metaValid
        valid = false;
        errors = [errors; metaErrors];
    end
    
    % Report errors if strict mode
    if ~valid && options.Strict
        errorMsg = sprintf('Schema validation failed for "%s" (version %s):\n  %s', ...
            spec.name, spec.version, strjoin(errors, newline + "  "));
        error('bct:schema:validationFailed', '%s', errorMsg);
    end
    return;
end

% Handle single-section schema (legacy)
[valid, errors] = validateSection(spec, data, spec.name);

if ~valid && options.Strict
    errorMsg = sprintf('Schema validation failed for "%s" (version %s):\n  %s', ...
        spec.name, spec.version, strjoin(errors, newline + "  "));
    error('bct:schema:validationFailed', '%s', errorMsg);
end

end

%%  =================================================================
%% SECTION VALIDATION HELPER
%% =================================================================

function [valid, errors] = validateSection(section, data, sectionName)
% Initialize
valid = true;
errors = {};

% Get fields from section
if isfield(section, 'fields')
    fields = section.fields;
else
    fields = section;  % Legacy: spec.fields directly
end

% Extract field names
fieldNames = fieldnames(fields);

%% Step 1: Check required fields
for i = 1:numel(fieldNames)
    fieldName = fieldNames{i};
    fieldSpec = fields.(fieldName);
    
    if fieldSpec.required && ~isfield(data, fieldName)
        valid = false;
        errors{end+1} = sprintf('[%s] Required field "%s" is missing.', sectionName, fieldName); %#ok<AGROW>
    end
end

%% Step 2-4: Validate each present field
for i = 1:numel(fieldNames)
    fieldName = fieldNames{i};
    
    % Skip if field not present (already reported above if required)
    if ~isfield(data, fieldName)
        continue;
    end
    
    fieldSpec = fields.(fieldName);
    value = data.(fieldName);
    
    % Check class
    if ~any(strcmp(class(value), fieldSpec.allowedClasses))
        valid = false;
        errors{end+1} = sprintf('[%s] Field "%s" has invalid class "%s". Allowed: %s', ... %#ok<AGROW>
            sectionName, fieldName, class(value), strjoin(fieldSpec.allowedClasses, ', '));
    end
    
    % Check allowed values if specified
    if isfield(fieldSpec, 'allowedValues') && ~isempty(fieldSpec.allowedValues)
        allowedVals = fieldSpec.allowedValues;
        if ~ismember(value, allowedVals)
            valid = false;
            errors{end+1} = sprintf('[%s] Field "%s" has invalid value. Allowed: %s', ... %#ok<AGROW>
                sectionName, fieldName, strjoin(string(allowedVals), ', '));
        end
    end
    
    % Skip dimension checks for non-numeric types
    if ~isnumeric(value)
        continue;
    end
    
    % Check dimensions
    if isfield(fieldSpec, 'ndims') && ~isempty(fieldSpec.ndims)
        actualNdims = ndims(value);
        if actualNdims ~= fieldSpec.ndims
            valid = false;
            errors{end+1} = sprintf('[%s] Field "%s" has %d dimensions, expected %d.', ... %#ok<AGROW>
                sectionName, fieldName, actualNdims, fieldSpec.ndims);
        end
    end
    
    % Check number of columns (for 2D arrays)
    if isfield(fieldSpec, 'ncols') && ~isempty(fieldSpec.ncols)
        actualCols = size(value, 2);
        if actualCols ~= fieldSpec.ncols
            valid = false;
            errors{end+1} = sprintf('[%s] Field "%s" has %d columns, expected %d.', ... %#ok<AGROW>
                sectionName, fieldName, actualCols, fieldSpec.ncols);
        end
    end
    
    % Kind-specific validation
    if isfield(fieldSpec, 'kind')
        switch fieldSpec.kind
            case "float"
                % Check for finite values (no NaN, no Inf)
                if ~all(isfinite(value(:)))
                    valid = false;
                    errors{end+1} = sprintf('[%s] Field "%s" contains non-finite values (NaN or Inf).', sectionName, fieldName); %#ok<AGROW>
                end
                
            case "index"
                % Check integer-valued (even if stored as double)
                if ~all(value(:) == round(value(:)))
                    valid = false;
                    errors{end+1} = sprintf('[%s] Field "%s" must contain integer values.', sectionName, fieldName); %#ok<AGROW>
                end
                
                % Check positive (1-based indexing)
                if isfield(fieldSpec, 'indexBase') && fieldSpec.indexBase == 1
                    if any(value(:) < 1)
                        valid = false;
                        errors{end+1} = sprintf('[%s] Field "%s" must contain positive indices (1-based).', sectionName, fieldName); %#ok<AGROW>
                    end
                elseif isfield(fieldSpec, 'indexBase') && fieldSpec.indexBase == 0
                    if any(value(:) < 0)
                        valid = false;
                        errors{end+1} = sprintf('[%s] Field "%s" must contain non-negative indices (0-based).', sectionName, fieldName); %#ok<AGROW>
                    end
                end
        end
    end
end

%% Step 5: Cross-field validation
if isfield(section, 'crossValidate') && isa(section.crossValidate, 'function_handle')
    try
        section.crossValidate(data);
    catch ME
        valid = false;
        errors{end+1} = sprintf('[%s] Cross-validation failed: %s', sectionName, ME.message); %#ok<AGROW>
    end
end

end
