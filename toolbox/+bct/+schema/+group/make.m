function attrs = make(varargin)
%MAKE Create compliant BCT group attributes structure
%
% Syntax:
%   attrs = bct.schema.group.make('path', ..., 'schema', ..., 'package', ...)
%
% Required Name-Value Arguments:
%   path    - Hierarchical path (string, e.g., '/geometry', '/operators')
%   schema  - Schema identifier with version (string, e.g., 'bct.manifold.geometry@1.0.0')
%   package - Source package (string, e.g., 'bct.manifold.geometry')
%
% Optional Name-Value Arguments:
%   timestamp   - Computation timestamp (datetime or string)
%   version     - Data version (string)
%   description - Human-readable description (string)
%
% Outputs:
%   attrs - Group attributes struct conforming to bct.schema.group
%
% Description:
%   Creates BCT-compliant group attributes from name-value pairs.
%   Validates the result against bct.schema.group.
%
%   The returned struct contains only the base group fields.
%   Domain-specific fields should be added after creation:
%
%     attrs = bct.schema.group.make(...);
%     attrs.precision = 'double';         % Domain-specific
%     attrs.massVariant = 'voronoi';      % Domain-specific
%
% Examples:
%   % Minimal geometry group
%   attrs = bct.schema.group.make(...
%       'path', '/geometry', ...
%       'schema', 'bct.manifold.geometry@1.0.0', ...
%       'package', 'bct.manifold.geometry');
%
%   % Operators group with description
%   attrs = bct.schema.group.make(...
%       'path', '/operators', ...
%       'schema', 'bct.manifold.operator@1.0.0', ...
%       'package', 'bct.manifold.operator', ...
%       'description', 'Differential operators on manifold');
%
%   % Add domain-specific fields
%   attrs.massVariant = 'voronoi';
%   attrs.stiffnessVariant = 'cotan';
%
%   % Eigenmodes group with timestamp
%   attrs = bct.schema.group.make(...
%       'path', '/eigenmodes', ...
%       'schema', 'bct.manifold.eigen@1.0.0', ...
%       'package', 'bct.manifold.eigen', ...
%       'timestamp', datetime('now'));
%   attrs.numModes = 100;
%   attrs.operator = 'Laplace-Beltrami';
%
% See also: bct.schema.group, bct.schema.group.validate

% Parse inputs using schema
p = inputParser;
p.KeepUnmatched = true;

% Get schema
spec = bct.schema.group();

% Add required parameters
p.addParameter('path', '', @(x) ischar(x) || isstring(x));
p.addParameter('schema', '', @(x) ischar(x) || isstring(x));
p.addParameter('package', '', @(x) ischar(x) || isstring(x));

% Add optional parameters
p.addParameter('timestamp', [], @(x) isempty(x) || isdatetime(x) || ischar(x) || isstring(x));
p.addParameter('version', '', @(x) ischar(x) || isstring(x));
p.addParameter('description', '', @(x) ischar(x) || isstring(x));

p.parse(varargin{:});

% Check required fields provided
if isempty(p.Results.path)
    error('bct:schema:group:make:MissingPath', ...
        'Required parameter "path" not provided');
end
if isempty(p.Results.schema)
    error('bct:schema:group:make:MissingSchema', ...
        'Required parameter "schema" not provided');
end
if isempty(p.Results.package)
    error('bct:schema:group:make:MissingPackage', ...
        'Required parameter "package" not provided');
end

% Build attributes struct with required fields
attrs = struct();
attrs.path = string(p.Results.path);
attrs.schema = string(p.Results.schema);
attrs.package = string(p.Results.package);

% Add optional fields if provided
if ~isempty(p.Results.timestamp)
    if isdatetime(p.Results.timestamp)
        attrs.timestamp = p.Results.timestamp;
    else
        attrs.timestamp = datetime(p.Results.timestamp);
    end
end

if ~isempty(p.Results.version)
    attrs.version = string(p.Results.version);
end

if ~isempty(p.Results.description)
    attrs.description = string(p.Results.description);
end

% Validate against schema
try
    bct.schema.group.validate(attrs);
catch ME
    warning('bct:schema:group:make:ValidationFailed', ...
        'Created group attributes failed validation: %s', ME.message);
    % Return attrs anyway but warn user
end

end
