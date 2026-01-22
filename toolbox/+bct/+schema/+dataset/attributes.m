function spec = attributes()
%ATTRIBUTES Return canonical schema for dataset attributes
%
% Syntax:
%   spec = bct.schema.dataset.attributes()
%
% Description:
%   Defines the authoritative schema for dataset attribute metadata.
%   All BCT datasets must include an .attributes struct conforming to
%   this specification.
%
%   Attributes provide essential metadata for:
%     - Data provenance (computedBy)
%     - Serialization (path, name)
%     - Interpretation (shape, dtype, units)
%     - Validation (support type)
%     - Documentation (description)
%
% Outputs:
%   spec - Structure with fields:
%     .name        - Schema name
%     .version     - Schema version
%     .fields      - Field specifications
%
% Attribute Fields (Standard):
%   name        - Dataset name (string)
%   path        - Hierarchical path for HDF5/Zarr (string, e.g., '/geometry/face/areas')
%   description - Human-readable description (string)
%   shape       - Data dimensions (numeric array, e.g., [28576, 1])
%   dtype       - Data type (string: 'double', 'single', 'uint32', etc.)
%   units       - Physical units (string, e.g., 'm^2', 'm', '1/m^2', '1' for dimensionless)
%   support     - Geometric support (string: 'vertex', 'face', 'edge', 'halfedge', etc.)
%   computedBy  - Function that computed this dataset (string, e.g., 'bct.manifold.geometry.face.areas')
%
% Optional Fields:
%   timestamp   - Computation timestamp (datetime or string)
%   version     - Data version (string)
%   source      - Data source (string)
%   indexBase   - Index base for connectivity (0 or 1)
%
% Examples:
%   % Get attributes schema
%   spec = bct.schema.dataset.attributes();
%
%   % Create compliant attributes
%   attrs = struct(...
%       'name', 'areas', ...
%       'path', '/geometry/face/areas', ...
%       'description', 'Area of each triangular face', ...
%       'shape', [28576, 1], ...
%       'dtype', 'double', ...
%       'units', 'm^2', ...
%       'support', 'face', ...
%       'computedBy', 'bct.manifold.geometry.face.areas');
%
%   % Validate attributes
%   isValid = bct.schema.dataset.attributes.validate(attrs);
%
% See also: bct.schema.dataset, bct.schema.dataset.attributes.make

% Schema metadata
spec.name = "bct.dataset.attributes";
spec.version = "1.0.0";
spec.description = "Canonical schema for dataset attribute metadata";
spec.package = "bct.schema";

%% Field Specifications
spec.fields = struct();

% --- name: Dataset identifier ---
spec.fields.name = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Dataset name (e.g., "areas", "normals", "eigenvalues")', ...
    'examples', ["areas", "centroids", "eigenvalues"], ...
    'normalize', @(x) string(x));

% --- path: Hierarchical path for serialization ---
spec.fields.path = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Hierarchical path for HDF5/Zarr (e.g., "/geometry/face/areas")', ...
    'pattern', '^/[\w/]+$', ...  % Must start with / and contain word chars and /
    'examples', ["/geometry/face/areas", "/topology/edges", "/eigenmodes/eigenvalues"], ...
    'normalize', @(x) string(x));

% --- description: Human-readable description ---
spec.fields.description = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Human-readable description of the dataset', ...
    'examples', ["Area of each triangular face", "3D vertex coordinates"], ...
    'normalize', @(x) string(x));

% --- shape: Data dimensions ---
spec.fields.shape = struct(...
    'required', true, ...
    'allowedClasses', ["double", "int32", "uint32"], ...
    'description', 'Data dimensions (e.g., [28576, 1] for vector, [28576, 3] for matrix)', ...
    'validate', @(x) isnumeric(x) && isvector(x) && all(x > 0), ...
    'examples', {[100, 1], [100, 3], [100, 100]}, ...
    'normalize', @(x) double(x(:)'));  % Row vector of dimensions

% --- dtype: Data type ---
spec.fields.dtype = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'MATLAB data type', ...
    'allowedValues', ["double", "single", "uint32", "uint16", "int32", "int64", "logical"], ...
    'examples', ["double", "uint32", "logical"], ...
    'normalize', @(x) string(lower(x)));

% --- units: Physical units ---
spec.fields.units = struct(...
    'required', false, ...  % Not all data has physical units (e.g., indices)
    'allowedClasses', ["string", "char"], ...
    'description', 'Physical units (e.g., "m^2", "m", "1/m^2", "1" for dimensionless)', ...
    'examples', ["m", "m^2", "m^3", "1/m^2", "rad", "1"], ...
    'normalize', @(x) string(x));

% --- support: Geometric support type ---
spec.fields.support = struct(...
    'required', false, ...  % Some datasets don't have geometric support (e.g., eigenvalues)
    'allowedClasses', ["string", "char"], ...
    'description', 'Geometric support type', ...
    'allowedValues', ["vertex", "face", "edge", "halfedge", "dualVertex", "dualFace", "dualEdge", "scalar", "none"], ...
    'examples', ["vertex", "face", "edge"], ...
    'normalize', @(x) string(lower(x)));

% --- computedBy: Provenance function ---
spec.fields.computedBy = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Function that computed this dataset (full package path)', ...
    'pattern', '^[\w.]+$', ...  % Must be valid MATLAB function path
    'examples', ["bct.manifold.geometry.face.areas", "bct.manifold.eigenmodes"], ...
    'normalize', @(x) string(x));

%% Optional Fields

% --- timestamp: Computation time ---
spec.fields.timestamp = struct(...
    'required', false, ...
    'allowedClasses', ["datetime", "string", "char"], ...
    'description', 'Timestamp when dataset was computed', ...
    'normalize', @normalizeTimestamp);

% --- version: Data version ---
spec.fields.version = struct(...
    'required', false, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Version of the data or schema', ...
    'normalize', @(x) string(x));

% --- source: Data source ---
spec.fields.source = struct(...
    'required', false, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Source of the data (file, computation, etc.)', ...
    'normalize', @(x) string(x));

% --- indexBase: Index convention ---
spec.fields.indexBase = struct(...
    'required', false, ...
    'allowedClasses', ["double", "int32"], ...
    'description', 'Index base for connectivity data (0 or 1)', ...
    'allowedValues', [0, 1], ...
    'default', 1, ...  % MATLAB default
    'normalize', @(x) double(x));

%% Validation
spec.validate = @validateAttributes;

%% Helper Functions
spec.make = @makeAttributes;

end

%% =================================================================
%% VALIDATION FUNCTION
%% =================================================================

function isValid = validateAttributes(attrs)
    %VALIDATEATTRIBUTES Validate attribute struct against schema
    %
    % Inputs:
    %   attrs - Attribute struct to validate
    %
    % Outputs:
    %   isValid - true if valid, error otherwise
    
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
        
        if fieldSpec.required && ~isfield(attrs, fieldName)
            error('bct:schema:attributes:MissingField', ...
                'Required attribute field missing: %s', fieldName);
        end
        
        % Validate field if present
        if isfield(attrs, fieldName)
            value = attrs.(fieldName);
            
            % Check allowed classes
            if isfield(fieldSpec, 'allowedClasses')
                if ~any(arrayfun(@(c) isa(value, char(c)), fieldSpec.allowedClasses))
                    error('bct:schema:attributes:InvalidType', ...
                        'Field %s has invalid type %s (expected: %s)', ...
                        fieldName, class(value), strjoin(fieldSpec.allowedClasses, ', '));
                end
            end
            
            % Check allowed values
            if isfield(fieldSpec, 'allowedValues')
                if isstring(value) || ischar(value)
                    value = string(value);
                end
                if ~ismember(value, fieldSpec.allowedValues)
                    error('bct:schema:attributes:InvalidValue', ...
                        'Field %s has invalid value "%s" (allowed: %s)', ...
                        fieldName, string(value), strjoin(string(fieldSpec.allowedValues), ', '));
                end
            end
            
            % Run custom validation if present
            if isfield(fieldSpec, 'validate') && isa(fieldSpec.validate, 'function_handle')
                try
                    fieldSpec.validate(value);
                catch ME
                    error('bct:schema:attributes:ValidationFailed', ...
                        'Validation failed for field %s: %s', fieldName, ME.message);
                end
            end
        end
    end
    
    isValid = true;
end

%% =================================================================
%% HELPER FUNCTIONS
%% =================================================================

function attrs = makeAttributes(varargin)
    %MAKEATTRIBUTES Create attribute struct from name-value pairs
    %
    % Syntax:
    %   attrs = bct.schema.dataset.attributes.make('name', value, ...)
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
    
    p = inputParser;
    p.KeepUnmatched = true;
    
    % Get schema
    spec = bct.schema.dataset.attributes();
    
    % Add parameters from schema
    fieldNames = fieldnames(spec.fields);
    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        fieldSpec = spec.fields.(fieldName);
        
        if fieldSpec.required
            p.addRequired(fieldName);
        else
            if isfield(fieldSpec, 'default')
                p.addParameter(fieldName, fieldSpec.default);
            else
                p.addParameter(fieldName, []);
            end
        end
    end
    
    p.parse(varargin{:});
    
    % Build attributes struct
    attrs = struct();
    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        if isfield(p.Results, fieldName) && ~isempty(p.Results.(fieldName))
            value = p.Results.(fieldName);
            
            % Normalize if normalizer provided
            fieldSpec = spec.fields.(fieldName);
            if isfield(fieldSpec, 'normalize') && isa(fieldSpec.normalize, 'function_handle')
                value = fieldSpec.normalize(value);
            end
            
            attrs.(fieldName) = value;
        end
    end
    
    % Validate
    validateAttributes(attrs);
end

function dt = normalizeTimestamp(x)
    %NORMALIZETIMESTAMP Convert various timestamp formats to datetime
    if isdatetime(x)
        dt = x;
    elseif ischar(x) || isstring(x)
        try
            dt = datetime(x, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
        catch
            dt = datetime(x);
        end
    else
        error('bct:schema:attributes:InvalidTimestamp', ...
            'Timestamp must be datetime, string, or char');
    end
end
