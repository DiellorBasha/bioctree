function dataset = make(value, varargin)
%MAKE Create a compliant BCT dataset structure
%
% Syntax:
%   dataset = bct.schema.dataset.make(value, 'name', ..., 'path', ...)
%   dataset = bct.schema.dataset.make(value, attributesStruct)
%
% Inputs:
%   value - The data array
%
% Name-Value Arguments:
%   All fields from bct.schema.dataset.attributes:
%     name        - Dataset name (required)
%     path        - Hierarchical path (required)
%     description - Description (required)
%     shape       - Data dimensions (auto-computed if not provided)
%     dtype       - Data type (auto-computed if not provided)
%     units       - Physical units (optional)
%     support     - Geometric support (optional)
%     computedBy  - Source function (required)
%     ... (see bct.schema.dataset.attributes for full list)
%
%   OR provide a complete attributes struct as second argument
%
% Outputs:
%   dataset - Structure with:
%             .value      - The data
%             .attributes - Metadata struct
%
% Description:
%   Creates a BCT-compliant dataset structure from data and metadata.
%   Automatically computes shape and dtype if not provided.
%   Validates the result against bct.schema.dataset.
%
% Examples:
%   % Minimal creation
%   dataset = bct.schema.dataset.make(rand(100, 3), ...
%       'name', 'normals', ...
%       'path', '/geometry/vertex/normals', ...
%       'description', 'Vertex normal vectors', ...
%       'units', '1', ...
%       'support', 'vertex', ...
%       'computedBy', 'bct.manifold.geometry.vertex.normals');
%
%   % With pre-built attributes
%   attrs = bct.schema.dataset.attributes.make(...
%       'name', 'areas', ...
%       'path', '/geometry/face/areas', ...
%       'description', 'Face areas', ...
%       'shape', [100, 1], ...
%       'dtype', 'double', ...
%       'units', 'm^2', ...
%       'support', 'face', ...
%       'computedBy', 'bct.manifold.geometry.face.areas');
%   dataset = bct.schema.dataset.make(faceAreas, attrs);
%
% See also: bct.schema.dataset, bct.schema.dataset.attributes

% Parse inputs
if nargin >= 2 && isstruct(varargin{1})
    % Second argument is complete attributes struct
    attrs = varargin{1};
else
    % Build attributes from name-value pairs
    % Auto-compute shape and dtype if not provided
    p = inputParser;
    p.KeepUnmatched = true;
    
    % Parse to check if shape/dtype provided
    p.addParameter('shape', size(value), @isnumeric);
    p.addParameter('dtype', class(value), @(x) ischar(x) || isstring(x));
    p.parse(varargin{:});
    
    % Create attributes using schema helper
    attrs = bct.schema.dataset.attributes.make(...
        'shape', p.Results.shape, ...
        'dtype', p.Results.dtype, ...
        varargin{:});
end

% Create dataset structure
dataset = struct();
dataset.value = value;
dataset.attributes = attrs;

% Validate
try
    bct.schema.dataset.validate(dataset);
catch ME
    warning('bct:schema:dataset:make:ValidationFailed', ...
        'Created dataset failed validation: %s', ME.message);
    % Return dataset anyway but warn user
end

end
