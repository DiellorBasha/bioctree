function params_out = validate(id, params)
%BCT.KERNEL.VALIDATE Validate and normalize kernel parameters
%
% Syntax:
%   params_out = bct.kernel.validate(id, params)
%
% Inputs:
%   id     - Kernel identifier (string)
%   params - Struct with parameter name-value pairs
%
% Outputs:
%   params_out - Validated and merged parameters (with defaults applied)
%
% Description:
%   Validates parameters against the kernel's ParamSchema and merges
%   with default values from the registry.
%
% Validation Rules:
%   - Missing parameters are filled from spec.Defaults
%   - Unknown parameters raise error
%   - Type and range constraints from ParamSchema are enforced
%
% Errors:
%   bct:kernel:InvalidParam - if parameter validation fails
%
% Example:
%   params = struct('sigma', 0.2);
%   params = bct.kernel.validate("Gaussian", params);
%   % params.mu will be filled from defaults
%
% See also: bct.kernel.bind, bct.kernel.get

arguments
    id (1,1) string
    params (1,1) struct
end

% Get kernel spec
[~, spec] = bct.kernel.get(id);

% Start with defaults
params_out = spec.Defaults;

% Merge provided parameters
provided_fields = fieldnames(params);
for i = 1:numel(provided_fields)
    field = provided_fields{i};
    
    % Check if parameter is recognized
    if ~isfield(spec.Defaults, field)
        error('bct:kernel:InvalidParam', ...
            'Unknown parameter "%s" for kernel "%s"', field, id);
    end
    
    % Get provided value
    value = params.(field);
    
    % Validate against schema if it exists
    if isfield(spec, 'ParamSchema') && isfield(spec.ParamSchema, field)
        schema = spec.ParamSchema.(field);
        
        % Type validation
        if isfield(schema, 'Type')
            if ~isa(value, schema.Type)
                error('bct:kernel:InvalidParam', ...
                    'Parameter "%s" must be of type %s', field, schema.Type);
            end
        end
        
        % Range validation
        if isfield(schema, 'Range')
            if value < schema.Range(1) || value > schema.Range(2)
                error('bct:kernel:InvalidParam', ...
                    'Parameter "%s" must be in range [%g, %g]', ...
                    field, schema.Range(1), schema.Range(2));
            end
        end
        
        % Positive constraint
        if isfield(schema, 'Positive') && schema.Positive
            if value <= 0
                error('bct:kernel:InvalidParam', ...
                    'Parameter "%s" must be positive', field);
            end
        end
    end
    
    % Apply validated value
    params_out.(field) = value;
end

end
