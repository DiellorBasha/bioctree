function isValid = validate(attrs)
%VALIDATE Validate attribute struct against schema
%
% Syntax:
%   isValid = bct.schema.dataset.attributes.validate(attrs)
%
% Inputs:
%   attrs - Attribute struct to validate
%
% Outputs:
%   isValid - true if valid, error otherwise
%
% Description:
%   Validates an attribute struct against the bct.schema.dataset.attributes
%   specification. Checks required fields, allowed classes, allowed values,
%   and custom validation functions.
%
% Examples:
%   attrs = struct('name', 'areas', 'path', '/geometry/face/areas', ...);
%   isValid = bct.schema.dataset.attributes.validate(attrs);
%
% See also: bct.schema.dataset.attributes, bct.schema.dataset.attributes.make

if ~isstruct(attrs)
    error('bct:schema:attributes:NotStruct', ...
        'Attributes must be a struct');
end

% Get schema
spec = bct.schema.dataset.attributes();

% Check required fields
requiredFields = fieldnames(spec.fields);
for i = 1:numel(requiredFields)
    fieldName = requiredFields{i};
    fieldSpec = spec.fields.(fieldName);
    
    % Store required flag to avoid comma-separated list expansion
    isRequired = fieldSpec.required;
    if isRequired && ~isfield(attrs, fieldName)
        error('bct:schema:attributes:MissingField', ...
            'Required attribute field missing: %s', fieldName);
    end
    
    % Validate field if present
    if isfield(attrs, fieldName)
        value = attrs.(fieldName);
        
        % Check allowed classes
        if isfield(fieldSpec, 'allowedClasses')
            allowedClasses = fieldSpec.allowedClasses;
            if ~any(arrayfun(@(c) isa(value, char(c)), allowedClasses))
                error('bct:schema:attributes:InvalidType', ...
                    'Field %s has invalid type %s (expected: %s)', ...
                    fieldName, class(value), strjoin(allowedClasses, ', '));
            end
        end
        
        % Check allowed values
        if isfield(fieldSpec, 'allowedValues')
            if isstring(value) || ischar(value)
                value = string(value);
            end
            allowedValues = fieldSpec.allowedValues;
            if ~ismember(value, allowedValues)
                error('bct:schema:attributes:InvalidValue', ...
                    'Field %s has invalid value "%s" (allowed: %s)', ...
                    fieldName, string(value), strjoin(string(allowedValues), ', '));
            end
        end
        
        % Run custom validation if present
        if isfield(fieldSpec, 'validate')
            validateFn = fieldSpec.validate;
            if isa(validateFn, 'function_handle')
                try
                    validateFn(value);
                catch ME
                    error('bct:schema:attributes:ValidationFailed', ...
                        'Validation failed for field %s: %s', fieldName, ME.message);
                end
            end
        end
    end
end

isValid = true;

end
