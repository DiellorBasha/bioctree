function spec = group()
%GROUP Return canonical schema specification for BCT group attributes
%
% Syntax:
%   spec = bct.schema.group()
%
% Description:
%   Defines the authoritative base schema for group-level attributes.
%   A group is a collection of related datasets (e.g., geometry, operators,
%   eigenmodes) with shared metadata.
%
%   All groups must have these common fields:
%     - path:    Hierarchical path for HDF5/Zarr (e.g., '/geometry', '/operators')
%     - schema:  Schema identifier with version (e.g., 'bct.manifold.geometry@1.0.0')
%     - package: Source package (e.g., 'bct.manifold.geometry')
%
%   Domain-specific groups extend this base with additional fields.
%
% Outputs:
%   spec - Structure with fields:
%     .name        - Schema name
%     .version     - Schema version string
%     .description - Human-readable description
%     .fields      - Required and optional field specifications
%     .validation  - Validation function handles
%
% Group Structure (Minimal):
%   group.attributes = struct(...
%       'path', '/geometry', ...
%       'schema', 'bct.manifold.geometry@1.0.0', ...
%       'package', 'bct.manifold.geometry')
%
% Group Structure (Extended):
%   group.attributes = struct(...
%       'path', '/geometry', ...
%       'schema', 'bct.manifold.geometry@1.0.0', ...
%       'package', 'bct.manifold.geometry', ...
%       'precision', 'double', ...              % Domain-specific
%       'circumcenterMethod', 'native', ...     % Domain-specific
%       'boundaryPolicy', 'error')              % Domain-specific
%
% Examples:
%   % Get group schema
%   spec = bct.schema.group();
%
%   % Create minimal group attributes
%   attrs = bct.schema.group.make(...
%       'path', '/geometry', ...
%       'schema', 'bct.manifold.geometry@1.0.0', ...
%       'package', 'bct.manifold.geometry');
%
%   % Extend with domain-specific fields
%   attrs.precision = 'double';
%   attrs.circumcenterMethod = 'native';
%
%   % Validate base fields
%   isValid = bct.schema.group.validate(attrs);
%
% See also: bct.schema.dataset, bct.schema.group.validate, bct.schema.group.make

% Schema metadata
spec.name = "bct.group";
spec.version = "1.0.0";
spec.description = "Base schema for BCT group-level attributes";
spec.package = "bct.schema";

%% Required Fields (Common to All Groups)
spec.fields = struct();

% --- path: Hierarchical path for serialization ---
spec.fields.path = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Hierarchical path for HDF5/Zarr (e.g., "/geometry", "/operators")', ...
    'pattern', '^/[a-zA-Z0-9_/]*$', ...  % Must start with / and contain word chars and /
    'examples', ["/geometry", "/operators", "/eigenmodes", "/topology", "/manifold"], ...
    'normalize', @(x) string(x));

% --- schema: Schema identifier with version ---
spec.fields.schema = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Schema identifier with version (e.g., "bct.manifold.geometry@1.0.0" or "bct.Manifold@1.1")', ...
    'pattern', '^[a-zA-Z0-9_.]+@\d+(\.\d+)?(\.\d+)?$', ...  % package@major[.minor][.patch]
    'examples', ["bct.manifold.geometry@1.0.0", "bct.Manifold@1.1", "bct.manifold.operator@1.0.0"], ...
    'normalize', @(x) string(x));

% --- package: Source package ---
spec.fields.package = struct(...
    'required', true, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Source package that generates this group', ...
    'pattern', '^[a-zA-Z0-9_.]+$', ...  % Valid MATLAB package path
    'examples', ["bct.manifold.geometry", "bct.manifold.operator", "bct.manifold.eigen"], ...
    'normalize', @(x) string(x));

%% Optional Fields (Common but not required)

% --- timestamp: Computation time ---
spec.fields.timestamp = struct(...
    'required', false, ...
    'allowedClasses', ["datetime", "string", "char"], ...
    'description', 'Timestamp when group was computed', ...
    'normalize', @normalizeTimestamp);

% --- version: Data version ---
spec.fields.version = struct(...
    'required', false, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Version of the data (separate from schema version)', ...
    'normalize', @(x) string(x));

% --- description: Human-readable description ---
spec.fields.description = struct(...
    'required', false, ...
    'allowedClasses', ["string", "char"], ...
    'description', 'Human-readable description of the group', ...
    'examples', ["Geometric properties of manifold", "Differential operators"], ...
    'normalize', @(x) string(x));

%% Validation
spec.validate = @validateGroup;

%% Helper Functions
spec.make = @makeGroup;

%% Documentation
spec.documentation = struct(...
    'purpose', 'Enforce uniform group attributes across all BCT packages', ...
    'usage', 'All group-level metadata should conform to this base schema', ...
    'extensibility', 'Domain-specific packages extend this with additional fields', ...
    'examples', struct(...
        'minimal', 'attrs = bct.schema.group.make("path", "/geometry", "schema", "bct.manifold.geometry@1.0.0", "package", "bct.manifold.geometry")', ...
        'extended', 'attrs.precision = "double"; attrs.boundaryPolicy = "error";'));

end

%% =================================================================
%% VALIDATION FUNCTION
%% =================================================================

function isValid = validateGroup(attrs)
    %VALIDATEGROUP Validate group attributes against base schema
    %
    % Inputs:
    %   attrs - Attribute struct to validate
    %
    % Outputs:
    %   isValid - true if valid, error otherwise
    
    if ~isstruct(attrs)
        error('bct:schema:group:NotStruct', ...
            'Group attributes must be a struct');
    end
    
    % Get schema
    spec = bct.schema.group();
    
    % Check required fields
    requiredFields = fieldnames(spec.fields);
    for i = 1:numel(requiredFields)
        fieldName = requiredFields{i};
        fieldSpec = spec.fields.(fieldName);
        
        if fieldSpec.required && ~isfield(attrs, fieldName)
            error('bct:schema:group:MissingField', ...
                'Required group attribute missing: %s', fieldName);
        end
        
        % Validate field if present
        if isfield(attrs, fieldName)
            value = attrs.(fieldName);
            
            % Check allowed classes
            if isfield(fieldSpec, 'allowedClasses')
                if ~any(arrayfun(@(c) isa(value, char(c)), fieldSpec.allowedClasses))
                    error('bct:schema:group:InvalidType', ...
                        'Field %s has invalid type %s (expected: %s)', ...
                        fieldName, class(value), strjoin(fieldSpec.allowedClasses, ', '));
                end
            end
            
            % Check pattern (for strings)
            if isfield(fieldSpec, 'pattern') && (isstring(value) || ischar(value))
                value_str = string(value);
                if ~matches(value_str, fieldSpec.pattern)
                    error('bct:schema:group:InvalidPattern', ...
                        'Field %s value "%s" does not match required pattern: %s', ...
                        fieldName, value_str, fieldSpec.pattern);
                end
            end
            
            % Run custom validation if present
            if isfield(fieldSpec, 'validate') && isa(fieldSpec.validate, 'function_handle')
                try
                    fieldSpec.validate(value);
                catch ME
                    error('bct:schema:group:ValidationFailed', ...
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

function attrs = makeGroup(varargin)
    %MAKEGROUP Create group attributes struct from name-value pairs
    %
    % Syntax:
    %   attrs = bct.schema.group.make('name', value, ...)
    %
    % Examples:
    %   % Minimal group
    %   attrs = bct.schema.group.make(...
    %       'path', '/geometry', ...
    %       'schema', 'bct.manifold.geometry@1.0.0', ...
    %       'package', 'bct.manifold.geometry');
    %
    %   % With optional fields
    %   attrs = bct.schema.group.make(...
    %       'path', '/operators', ...
    %       'schema', 'bct.manifold.operator@1.0.0', ...
    %       'package', 'bct.manifold.operator', ...
    %       'description', 'Differential operators on manifold');
    
    p = inputParser;
    p.KeepUnmatched = true;
    
    % Get schema
    spec = bct.schema.group();
    
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
    validateGroup(attrs);
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
        error('bct:schema:group:InvalidTimestamp', ...
            'Timestamp must be datetime, string, or char');
    end
end
