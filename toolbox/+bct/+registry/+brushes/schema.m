function S = schema()
%BCT.REGISTRY.BRUSHES.SCHEMA  BrushSpec schema definition
%
%   S = bct.registry.brushes.schema()
%
% Purpose:
%   Returns declarative description of expected fields and invariants
%   for brush specifications. Enables centralized validation and tooling.
%
% Output:
%   S - struct describing:
%       RequiredFields  - Fields that must be present
%       OptionalFields  - Fields that may be present
%       FieldTypes      - Expected types for each field
%       AllowedValues   - Enumerated values for categorical fields
%       ValidateEntry   - Function handle for entry validation
%
% See also: bct.registry.brushes.defs, bct.registry.brushes.validate

    S = struct();
    
    % Required fields (must be present in all brush specs)
    S.RequiredFields = [
        "Id"
        "Category"
        "AxisKinds"
        "ParamNames"
        "DefaultParams"
        "ParamRanges"
        "Evaluate"
    ];
    
    % Optional fields (may be present)
    S.OptionalFields = [
        "Name"
        "Tags"
        "Requires"
        "OutputDims"
        "Description"
        "Examples"
        "Performance"
    ];
    
    % Expected field types
    S.FieldTypes = struct(...
        'Id',           "string", ...
        'Category',     "string", ...
        'AxisKinds',    "string array", ...
        'ParamNames',   "string array", ...
        'DefaultParams', "function_handle", ...
        'ParamRanges',  "function_handle", ...
        'Evaluate',     "function_handle", ...
        'Name',         "string", ...
        'Tags',         "string array", ...
        'Requires',     "string array", ...
        'OutputDims',   "string", ...
        'Description',  "string" ...
    );
    
    % Allowed values for enumerated fields
    S.AllowedValues = struct(...
        'Category',    ["patch", "trajectory", "time", "dynamic"], ...
        'AxisKinds',   ["spatial", "spatiotemporal"], ...
        'Requires',    ["Graph", "FEM", "DEC", "Eigenpairs"], ...
        'OutputDims',  ["spatial", "spatiotemporal"] ...
    );
    
    % Validation function
    S.ValidateEntry = @validateBrushSpec;
end

function validateBrushSpec(spec)
%VALIDATEBRUSHSPEC  Validate individual brush specification
%
% Checks:
%   - Required fields present
%   - Field types correct
%   - Enumerated values valid
%   - Function handles have correct signatures

    schema = bct.registry.brushes.schema();
    
    % Check required fields
    for i = 1:length(schema.RequiredFields)
        field = schema.RequiredFields(i);
        if ~isfield(spec, field)
            error('bct:registry:brushes:MissingField', ...
                'Required field "%s" missing in brush "%s"', ...
                field, getIdSafely(spec));
        end
    end
    
    % Validate field types
    validateFieldTypes(spec, schema);
    
    % Validate enumerated values
    validateEnumeratedFields(spec, schema);
    
    % Validate function handle signatures
    validateFunctionHandles(spec);
    
    % Validate parameter names consistency
    validateParameterConsistency(spec);
end

function id = getIdSafely(spec)
%GETIDSAFELY  Get Id field safely, return 'unknown' if missing
    if isfield(spec, 'Id')
        id = spec.Id;
    else
        id = "unknown";
    end
end

function validateFieldTypes(spec, schema)
%VALIDATEFIELDTYPES  Validate field types match schema

    fields = fieldnames(spec);
    
    for i = 1:length(fields)
        fieldName = string(fields{i});
        
        % Skip if not in schema
        if ~isfield(schema.FieldTypes, fieldName)
            continue;
        end
        
        expectedType = schema.FieldTypes.(fieldName);
        value = spec.(fieldName);
        
        % Type-specific validation
        switch expectedType
            case "string"
                if ~isstring(value) && ~ischar(value)
                    error('bct:registry:brushes:InvalidType', ...
                        'Field "%s" must be string, got %s', ...
                        fieldName, class(value));
                end
                
            case "string array"
                if ~isstring(value) && ~iscellstr(value) %#ok<ISCLSTR>
                    error('bct:registry:brushes:InvalidType', ...
                        'Field "%s" must be string array, got %s', ...
                        fieldName, class(value));
                end
                
            case "function_handle"
                if ~isa(value, 'function_handle')
                    error('bct:registry:brushes:InvalidType', ...
                        'Field "%s" must be function handle, got %s', ...
                        fieldName, class(value));
                end
        end
    end
end

function validateEnumeratedFields(spec, schema)
%VALIDATEENUMERATEDFIELDS  Validate enumerated field values

    enumFields = fieldnames(schema.AllowedValues);
    
    for i = 1:length(enumFields)
        fieldName = enumFields{i};
        
        if ~isfield(spec, fieldName)
            continue;
        end
        
        value = string(spec.(fieldName));
        allowedValues = schema.AllowedValues.(fieldName);
        
        % Check if all values are in allowed set
        if any(~ismember(value, allowedValues))
            error('bct:registry:brushes:InvalidValue', ...
                'Field "%s" has invalid value. Allowed: [%s]', ...
                fieldName, strjoin(allowedValues, ', '));
        end
    end
end

function validateFunctionHandles(spec)
%VALIDATEFUNCTIONHANDLES  Validate function handle signatures

    % Validate DefaultParams: @(manifold)->struct
    if isfield(spec, 'DefaultParams')
        try
            % Test with nargin/nargout
            if nargin(spec.DefaultParams) ~= 1
                error('DefaultParams must accept 1 input (manifold)');
            end
        catch ME
            % Skip validation for built-in or anonymous functions
            if ~contains(ME.message, 'built-in')
                warning('bct:registry:brushes:ValidationWarning', ...
                    'Could not validate DefaultParams signature: %s', ME.message);
            end
        end
    end
    
    % Validate ParamRanges: @(manifold)->struct
    if isfield(spec, 'ParamRanges')
        try
            if nargin(spec.ParamRanges) ~= 1
                error('ParamRanges must accept 1 input (manifold)');
            end
        catch ME
            if ~contains(ME.message, 'built-in')
                warning('bct:registry:brushes:ValidationWarning', ...
                    'Could not validate ParamRanges signature: %s', ME.message);
            end
        end
    end
    
    % Validate Evaluate: @(manifold,params)->w
    if isfield(spec, 'Evaluate')
        try
            if nargin(spec.Evaluate) ~= 2
                error('Evaluate must accept 2 inputs (manifold, params)');
            end
        catch ME
            if ~contains(ME.message, 'built-in')
                warning('bct:registry:brushes:ValidationWarning', ...
                    'Could not validate Evaluate signature: %s', ME.message);
            end
        end
    end
end

function validateParameterConsistency(spec)
%VALIDATEPARAMETERCONSISTENCY  Ensure parameter names are consistent

    if ~isfield(spec, 'ParamNames') || isempty(spec.ParamNames)
        return;
    end
    
    paramNames = string(spec.ParamNames);
    
    % Check for duplicates
    if length(paramNames) ~= length(unique(paramNames))
        error('bct:registry:brushes:DuplicateParamNames', ...
            'Duplicate parameter names in brush "%s"', spec.Id);
    end
    
    % ParamNames should be sorted for consistency (optional but recommended)
    % Note: We don't enforce this as some brushes may have logical ordering
end
