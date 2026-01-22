function spec = dataset()
%DATASET Return canonical schema specification for BCT datasets
%
% Syntax:
%   spec = bct.schema.dataset()
%
% Description:
%   Defines the authoritative schema for all BCT datasets. A dataset is the
%   fundamental data structure used throughout BCT, consisting of:
%     - .value      : The actual data (array, matrix, tensor)
%     - .attributes : Metadata struct describing the dataset
%
%   This schema enforces consistency across all BCT packages (manifold,
%   geometry, topology, operators, eigenmodes, fields, etc.).
%
% Outputs:
%   spec - Structure with fields:
%     .name        - Schema name
%     .version     - Schema version string
%     .description - Human-readable description
%     .structure   - Required structure fields (.value, .attributes)
%     .validation  - Validation function handles
%
% Dataset Structure:
%   dataset = struct(...
%       'value', <data array>, ...
%       'attributes', <metadata struct>)
%
%   The .value field contains the actual data.
%   The .attributes field follows bct.schema.dataset.attributes spec.
%
% Examples:
%   % Get dataset schema
%   spec = bct.schema.dataset();
%
%   % Validate a dataset structure
%   dataset = struct('value', rand(100, 3), 'attributes', attrs);
%   isValid = bct.schema.dataset.validate(dataset);
%
%   % Create a compliant dataset
%   dataset.value = rand(100, 1);
%   dataset.attributes = bct.schema.dataset.attributes.make(...
%       'name', 'myData', ...
%       'path', '/my/data', ...
%       'shape', [100, 1], ...
%       'dtype', 'double');
%
% See also: bct.schema.dataset.attributes, bct.schema.dataset.validate

% Schema metadata
spec.name = "bct.dataset";
spec.version = "1.0.0";
spec.description = "Canonical schema for BCT datasets with value and attributes";
spec.package = "bct.schema";

%% Required Structure
spec.structure = struct();

% .value field - The actual data
spec.structure.value = struct(...
    'required', true, ...
    'description', 'The actual data array, matrix, or tensor', ...
    'allowedClasses', ["double", "single", "uint32", "uint16", "int32", "int64", "logical", "sparse"], ...
    'validate', @validateValue);

% .attributes field - Metadata describing the dataset
spec.structure.attributes = struct(...
    'required', true, ...
    'description', 'Metadata struct describing the dataset', ...
    'allowedClasses', ["struct"], ...
    'schema', 'bct.schema.dataset.attributes', ...
    'validate', @validateAttributes);

%% Validation Functions
spec.validate = @validateDataset;

%% HDF5/Zarr Serialization
% Path structure for hierarchical storage
spec.serialization = struct(...
    'format', ["HDF5", "Zarr"], ...
    'valueKey', 'value', ...  % Dataset data stored under this key
    'attributesKey', 'attributes', ...  % Metadata stored as attributes
    'pathSeparator', '/');

%% Documentation
spec.documentation = struct(...
    'purpose', 'Enforce uniform dataset structure across all BCT packages', ...
    'usage', 'All computed data in BCT should follow this schema', ...
    'examples', struct(...
        'simple', 'dataset.value = data; dataset.attributes = attrs;', ...
        'validation', 'bct.schema.dataset.validate(dataset)'));

end

%% =================================================================
%% VALIDATION FUNCTIONS
%% =================================================================

function validateValue(value)
    %VALIDATEVALUE Validate the .value field of a dataset
    %
    % Requirements:
    %   - Must be a numeric or logical array
    %   - Cannot be empty
    %   - Can be sparse or full
    
    if isempty(value)
        error('bct:schema:dataset:EmptyValue', ...
            'Dataset .value cannot be empty');
    end
    
    if ~isnumeric(value) && ~islogical(value)
        error('bct:schema:dataset:InvalidValueType', ...
            'Dataset .value must be numeric or logical, got %s', class(value));
    end
end

function validateAttributes(attrs)
    %VALIDATEATTRIBUTES Validate the .attributes field of a dataset
    %
    % Requirements:
    %   - Must be a struct
    %   - Must conform to bct.schema.dataset.attributes
    
    if ~isstruct(attrs)
        error('bct:schema:dataset:InvalidAttributesType', ...
            'Dataset .attributes must be a struct, got %s', class(attrs));
    end
    
    % Validate against dataset attributes schema
    attrSpec = bct.schema.dataset.attributes();
    
    % Check required fields
    requiredFields = fieldnames(attrSpec.fields);
    requiredFields = requiredFields(structfun(@(f) f.required, attrSpec.fields));
    
    for i = 1:numel(requiredFields)
        fieldName = requiredFields{i};
        if ~isfield(attrs, fieldName)
            error('bct:schema:dataset:MissingAttribute', ...
                'Dataset .attributes missing required field: %s', fieldName);
        end
    end
end

function isValid = validateDataset(dataset)
    %VALIDATEDATASET Validate complete dataset structure
    %
    % Inputs:
    %   dataset - Structure to validate
    %
    % Outputs:
    %   isValid - true if dataset is valid, false otherwise
    %           (or throws error if strict validation)
    
    try
        % Check structure has required fields
        if ~isstruct(dataset)
            error('bct:schema:dataset:NotStruct', ...
                'Dataset must be a struct');
        end
        
        if ~isfield(dataset, 'value')
            error('bct:schema:dataset:MissingValue', ...
                'Dataset must have .value field');
        end
        
        if ~isfield(dataset, 'attributes')
            error('bct:schema:dataset:MissingAttributes', ...
                'Dataset must have .attributes field');
        end
        
        % Validate individual fields
        validateValue(dataset.value);
        validateAttributes(dataset.attributes);
        
        % Validation passed
        isValid = true;
        
    catch ME
        % Validation failed
        warning('bct:schema:dataset:ValidationFailed', ...
            'Dataset validation failed: %s', ME.message);
        isValid = false;
        rethrow(ME);
    end
end
