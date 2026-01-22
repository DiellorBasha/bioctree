function attrs = make(varargin)
%MAKE Create attribute struct from name-value pairs
%
% Syntax:
%   attrs = bct.schema.dataset.attributes.make('name', value, ...)
%
% Inputs (Name-Value Pairs):
%   All fields from bct.schema.dataset.attributes:
%     name        - Dataset name (required)
%     path        - Hierarchical path (required)
%     description - Description (required)
%     shape       - Data dimensions (required)
%     dtype       - Data type (required)
%     units       - Physical units (optional)
%     support     - Geometric support (optional)
%     computedBy  - Source function (required)
%     ... (see bct.schema.dataset.attributes for full list)
%
% Outputs:
%   attrs - Attribute struct
%
% Examples:
%   attrs = bct.schema.dataset.attributes.make(...
%       'name', 'areas', ...
%       'path', '/geometry/face/areas', ...
%       'description', 'Face areas', ...
%       'shape', [100, 1], ...
%       'dtype', 'double', ...
%       'units', 'm^2', ...
%       'support', 'face', ...
%       'computedBy', 'bct.manifold.geometry.face.areas');
%
% See also: bct.schema.dataset.attributes, bct.schema.dataset.make

p = inputParser;
p.KeepUnmatched = false;  % Catch typos

% Get schema
spec = bct.schema.dataset.attributes();

% Add parameters from schema - use addParameter for all to support name-value pairs
fieldNames = fieldnames(spec.fields);
for i = 1:numel(fieldNames)
    fieldName = fieldNames{i};
    fieldSpec = spec.fields.(fieldName);
    
    % Use addParameter for all fields (required will be checked during validation)
    if isfield(fieldSpec, 'default')
        p.addParameter(fieldName, fieldSpec.default);
    else
        p.addParameter(fieldName, []);
    end
end

p.parse(varargin{:});

% Build attributes struct
attrs = struct();
for i = 1:numel(fieldNames)
    fieldName = fieldNames{i};
    fieldSpec = spec.fields.(fieldName);
    
    % Check if field was provided
    if isfield(p.Results, fieldName) && ~isempty(p.Results.(fieldName))
        value = p.Results.(fieldName);
        
        % Normalize if normalizer provided
        if isfield(fieldSpec, 'normalize')
            normalizeFn = fieldSpec.normalize;
            if isa(normalizeFn, 'function_handle')
                value = normalizeFn(value);
            end
        end
        
        attrs.(fieldName) = value;
    elseif fieldSpec.required
        error('bct:schema:dataset:attributes:make:MissingRequired', ...
            'Required field ''%s'' not provided', fieldName);
    end
end

% Validate
bct.schema.dataset.attributes.validate(attrs);

end
