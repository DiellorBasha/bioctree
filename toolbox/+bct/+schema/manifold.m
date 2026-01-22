function spec = manifold()
%MANIFOLD Return canonical schema specification for BCT manifold structure
%
% Syntax:
%   spec = bct.schema.manifold()
%
% Description:
%   Defines the authoritative top-level schema for manifold structures in BCT.
%   A manifold structure contains:
%     - .Vertices:   [N×3] vertex coordinates (direct array, not .value structure)
%     - .Faces:      [M×3] face connectivity (direct array, not .value structure)
%     - .Edges:      [E×2] edge connectivity (direct array, not .value structure)
%     - .Attributes: Group-level metadata + dataset attributes for V, F, E
%     - .Cache:      Cached subgroups (geometry, topology, operators, eigenmodes)
%
%   This schema is used by bct.Manifold class to ensure consistency
%   in manifold representation across BCT.
%
% Outputs:
%   spec - Structure with fields:
%     .name         - Schema name
%     .version      - Schema version string
%     .description  - Human-readable description
%     .attributes   - Group attributes specification
%     .arrays       - Top-level array specifications (Vertices, Faces, Edges)
%     .subgroups    - Subgroup specifications (geometry, topology, operators, eigenmodes)
%     .validation   - Validation function handles
%
% Manifold Structure:
%   M = struct(...
%       'Vertices', V, ...        % [N×3] direct array (exception)
%       'Faces', F, ...           % [M×3] direct array (exception)
%       'Edges', E, ...           % [E×2] direct array (exception)
%       'Attributes', struct(...
%           'path', '/manifold', ...
%           'schema', 'bct.Manifold@1.1', ...
%           'package', 'bct', ...
%           'ID', 'fsaverage_rh_pial', ...
%           'Metric', struct(...), ...
%           'FaceWinding', 'CCW', ...
%           'vertices', struct('attributes', ...), ...
%           'faces', struct('attributes', ...), ...
%           'edges', struct('attributes', ...)), ...
%       'Cache', struct(...))
%
% Examples:
%   % Get manifold schema
%   spec = bct.schema.manifold();
%
%   % Validate manifold structure
%   M = bct.Manifold(V, F);
%   isValid = bct.schema.manifold.validate(M);
%
% See also: bct.Manifold, bct.schema.geometry, bct.schema.topology, 
%           bct.schema.operators, bct.schema.eigenmodes

% Schema metadata
spec.name = "bct.manifold";
spec.version = "1.1.0";
spec.description = "Schema for top-level manifold structures (complete mesh representation)";
spec.package = "bct.schema";

%% Group Attributes (extends bct.schema.group)
spec.attributes = struct();

% Base fields (from bct.schema.group)
spec.attributes.base = struct(...
    'path', '/manifold', ...
    'schema', 'bct.Manifold@1.1', ...
    'package', 'bct');

% Manifold-specific optional fields
spec.attributes.optional = struct();

spec.attributes.optional.ID = struct(...
    'type', 'string', ...
    'description', 'Manifold identifier (e.g., "fsaverage_rh_pial")', ...
    'default', "");

spec.attributes.optional.Metric = struct(...
    'type', 'struct', ...
    'description', 'Metric information (units, scale, rescalingHistory)', ...
    'fields', struct(...
        'units', 'm', ...
        'scale', 1.0, ...
        'rescalingHistory', struct.empty));

spec.attributes.optional.FaceWinding = struct(...
    'type', 'string', ...
    'description', 'Face winding order', ...
    'allowedValues', ["CCW", "CW"], ...
    'default', "CCW");

spec.attributes.optional.Source = struct(...
    'type', 'string', ...
    'description', 'Data source or provenance', ...
    'default', "");

spec.attributes.optional.Description = struct(...
    'type', 'string', ...
    'description', 'Human-readable description', ...
    'default', "");

%% Top-Level Array Specifications (NOT .value structures)
% These are direct arrays as exceptions to the dataset pattern
spec.arrays = struct();

spec.arrays.Vertices = struct(...
    'name', 'Vertices', ...
    'description', 'Vertex coordinates in 3D space', ...
    'shape', @(nV) [nV, 3], ...
    'dtype', 'double', ...
    'units', 'm', ...
    'support', 'vertex');

spec.arrays.Faces = struct(...
    'name', 'Faces', ...
    'description', 'Face connectivity (indices into Vertices)', ...
    'shape', @(nF) [nF, 3], ...
    'dtype', 'uint32', ...
    'units', '1', ...
    'support', 'face');

spec.arrays.Edges = struct(...
    'name', 'Edges', ...
    'description', 'Edge connectivity (unique undirected edges)', ...
    'shape', @(nE) [nE, 2], ...
    'dtype', 'uint32', ...
    'units', '1', ...
    'support', 'edge');

%% Dataset Attributes for Top-Level Arrays
% While V, F, E are direct arrays, they have associated metadata in Attributes
spec.datasetAttributes = struct();

spec.datasetAttributes.vertices = struct(...
    'name', 'vertices', ...
    'path', '/manifold/vertices', ...
    'description', 'Vertex coordinates dataset metadata', ...
    'computedBy', 'bct.Manifold');

spec.datasetAttributes.faces = struct(...
    'name', 'faces', ...
    'path', '/manifold/faces', ...
    'description', 'Face connectivity dataset metadata', ...
    'computedBy', 'bct.Manifold');

spec.datasetAttributes.edges = struct(...
    'name', 'edges', ...
    'path', '/manifold/edges', ...
    'description', 'Edge connectivity dataset metadata', ...
    'computedBy', 'bct.manifold.topology.edges');

%% Subgroup Specifications
spec.subgroups = struct();

spec.subgroups.geometry = struct(...
    'name', 'geometry', ...
    'schema', 'bct.schema.geometry', ...
    'description', 'Geometric properties (areas, normals, tangents, etc.)', ...
    'cacheable', true, ...
    'validator', @() bct.schema.geometry());

spec.subgroups.topology = struct(...
    'name', 'topology', ...
    'schema', 'bct.schema.topology', ...
    'description', 'Topological properties (adjacency, edges, connectivity)', ...
    'cacheable', true, ...
    'validator', @() bct.schema.topology());

spec.subgroups.operators = struct(...
    'name', 'operators', ...
    'schema', 'bct.schema.operators', ...
    'description', 'Differential operators (Laplacian, gradient, DEC)', ...
    'cacheable', true, ...
    'validator', @() bct.schema.operators());

spec.subgroups.eigenmodes = struct(...
    'name', 'eigenmodes', ...
    'schema', 'bct.schema.eigenmodes', ...
    'description', 'Spectral decomposition (eigenvalues, eigenvectors)', ...
    'cacheable', true, ...
    'validator', @() bct.schema.eigenmodes());

%% Structure Specification
spec.structure = struct();
spec.structure.required = ["Vertices", "Faces", "Edges", "Attributes"];
spec.structure.optional = ["Cache"];
spec.structure.description = 'Manifold must have Vertices, Faces, Edges arrays and Attributes';

%% Cache Structure
spec.cache = struct();
spec.cache.namespaces = ["geometry", "topology", "halfedge", "operators", "eigenmodes", "health"];
spec.cache.structure = struct(...
    'data', struct(), ...
    'meta', struct());

%% Validation
spec.validate = @validateManifold;

%% Helper Functions
spec.make = @makeManifold;

%% Documentation
spec.documentation = struct(...
    'purpose', 'Enforce uniform manifold structure across BCT', ...
    'usage', 'All manifold representations should conform to this schema', ...
    'examples', struct(...
        'create', 'M = bct.Manifold(V, F)', ...
        'validate', 'bct.schema.manifold.validate(M)', ...
        'access', 'V = M.Vertices; F = M.Faces; geom = M.geometry()'));

end

%% =================================================================
%% VALIDATION FUNCTIONS
%% =================================================================

function isValid = validateManifold(M, varargin)
    %VALIDATEMANIFOLD Validate complete manifold structure
    %
    % Inputs:
    %   M - Manifold structure or object to validate
    %
    % Name-Value Arguments:
    %   Strict - true (default) to throw errors, false to return report
    %
    % Outputs:
    %   isValid - true if valid, false otherwise
    
    p = inputParser;
    p.addRequired('M');
    p.addParameter('Strict', true, @islogical);
    p.parse(M, varargin{:});
    
    strict = p.Results.Strict;
    
    try
        % Get schema
        spec = bct.schema.manifold();
        
        %% Check if object or struct
        isObject = isa(M, 'bct.Manifold');
        isStruct = isstruct(M);
        
        if ~isObject && ~isStruct
            error('bct:schema:manifold:InvalidType', ...
                'Manifold must be bct.Manifold object or struct');
        end
        
        %% Check required fields
        requiredFields = spec.structure.required;
        for i = 1:numel(requiredFields)
            field = requiredFields(i);
            
            % Check field existence
            if isObject
                if ~isprop(M, field)
                    error('bct:schema:manifold:MissingProperty', ...
                        'Required property missing: %s', field);
                end
            else
                if ~isfield(M, field)
                    error('bct:schema:manifold:MissingField', ...
                        'Required field missing: %s', field);
                end
            end
        end
        
        %% Validate top-level arrays
        % Vertices
        V = M.Vertices;
        if ~isnumeric(V) || size(V, 2) ~= 3
            error('bct:schema:manifold:InvalidVertices', ...
                'Vertices must be [N×3] numeric array');
        end
        if ~isa(V, 'double')
            warning('bct:schema:manifold:VerticesNotDouble', ...
                'Vertices should be double precision');
        end
        
        % Faces
        F = M.Faces;
        if ~isnumeric(F) || size(F, 2) ~= 3
            error('bct:schema:manifold:InvalidFaces', ...
                'Faces must be [M×3] numeric array');
        end
        if ~isa(F, 'uint32')
            warning('bct:schema:manifold:FacesNotUint32', ...
                'Faces should be uint32 type');
        end
        
        % Edges
        E = M.Edges;
        if ~isnumeric(E) || size(E, 2) ~= 2
            error('bct:schema:manifold:InvalidEdges', ...
                'Edges must be [E×2] numeric array');
        end
        if ~isa(E, 'uint32')
            warning('bct:schema:manifold:EdgesNotUint32', ...
                'Edges should be uint32 type');
        end
        
        %% Validate dimensions
        nV = size(V, 1);
        nF = size(F, 1);
        nE = size(E, 1);
        
        % Check face indices are valid
        if any(F(:) < 1) || any(F(:) > nV)
            error('bct:schema:manifold:InvalidFaceIndices', ...
                'Face indices must be in range [1, %d]', nV);
        end
        
        % Check edge indices are valid
        if any(E(:) < 1) || any(E(:) > nV)
            error('bct:schema:manifold:InvalidEdgeIndices', ...
                'Edge indices must be in range [1, %d]', nV);
        end
        
        %% Validate Attributes
        attrs = M.Attributes;
        
        % Validate base group fields
        bct.schema.group.validate(attrs);
        
        % Check dataset attributes exist
        if ~isfield(attrs, 'vertices') || ~isfield(attrs.vertices, 'attributes')
            warning('bct:schema:manifold:MissingDatasetAttributes', ...
                'Missing vertices.attributes metadata');
        end
        if ~isfield(attrs, 'faces') || ~isfield(attrs.faces, 'attributes')
            warning('bct:schema:manifold:MissingDatasetAttributes', ...
                'Missing faces.attributes metadata');
        end
        if ~isfield(attrs, 'edges') || ~isfield(attrs.edges, 'attributes')
            warning('bct:schema:manifold:MissingDatasetAttributes', ...
                'Missing edges.attributes metadata');
        end
        
        % Validate optional manifold-specific attributes (if present)
        optionalAttrs = fieldnames(spec.attributes.optional);
        for i = 1:numel(optionalAttrs)
            fieldName = optionalAttrs{i};
            if isfield(attrs, fieldName)
                fieldSpec = spec.attributes.optional.(fieldName);
                value = attrs.(fieldName);
                
                % Type check
                if isfield(fieldSpec, 'type')
                    switch fieldSpec.type
                        case 'string'
                            if ~isstring(value) && ~ischar(value) && ~isempty(value)
                                error('bct:schema:manifold:InvalidType', ...
                                    'Attribute %s must be string', fieldName);
                            end
                        case 'struct'
                            if ~isstruct(value) && ~isempty(value)
                                error('bct:schema:manifold:InvalidType', ...
                                    'Attribute %s must be struct', fieldName);
                            end
                    end
                end
                
                % Allowed values check
                if isfield(fieldSpec, 'allowedValues')
                    if isstring(value) || ischar(value)
                        value = string(value);
                    end
                    if ~ismember(value, fieldSpec.allowedValues)
                        error('bct:schema:manifold:InvalidValue', ...
                            'Attribute %s has invalid value "%s"', fieldName, string(value));
                    end
                end
            end
        end
        
        %% Validate Cache structure (if present)
        if isObject || isfield(M, 'Cache')
            cache = M.Cache;
            if ~isstruct(cache)
                error('bct:schema:manifold:InvalidCache', ...
                    'Cache must be a struct');
            end
            
            % Check cache namespaces
            expectedNamespaces = spec.cache.namespaces;
            for i = 1:numel(expectedNamespaces)
                ns = expectedNamespaces(i);
                if ~isfield(cache, ns)
                    warning('bct:schema:manifold:MissingCacheNamespace', ...
                        'Missing cache namespace: %s', ns);
                end
            end
        end
        
        %% Validation passed
        isValid = true;
        
    catch ME
        if strict
            rethrow(ME);
        end
        warning('bct:schema:manifold:ValidationFailed', ...
            'Manifold validation failed: %s', ME.message);
        isValid = false;
    end
end

function M = makeManifold(V, F, varargin)
    %MAKEMANIFOLD Create schema-compliant manifold structure
    %
    % Syntax:
    %   M = bct.schema.manifold.make(V, F)
    %   M = bct.schema.manifold.make(V, F, 'ID', 'my_mesh', ...)
    %
    % Inputs:
    %   V - [N×3] vertex coordinates
    %   F - [M×3] face connectivity
    %
    % Optional Name-Value Arguments:
    %   ID          - Manifold identifier
    %   Source      - Data source/provenance
    %   Description - Human-readable description
    %
    % Examples:
    %   M = bct.schema.manifold.make(V, F);
    %   M = bct.schema.manifold.make(V, F, 'ID', 'fsaverage_rh_pial');
    
    p = inputParser;
    p.addRequired('V', @(x) isnumeric(x) && size(x, 2) == 3);
    p.addRequired('F', @(x) isnumeric(x) && size(x, 2) == 3);
    p.addParameter('ID', "", @(x) ischar(x) || isstring(x));
    p.addParameter('Source', "", @(x) ischar(x) || isstring(x));
    p.addParameter('Description', "", @(x) ischar(x) || isstring(x));
    p.parse(V, F, varargin{:});
    
    % Use the actual Manifold constructor
    M = bct.Manifold(V, F);
    
    % Set optional attributes if provided
    if ~isempty(p.Results.ID) && p.Results.ID ~= ""
        M.Attributes.ID = string(p.Results.ID);
    end
    if ~isempty(p.Results.Source) && p.Results.Source ~= ""
        M.Attributes.Source = string(p.Results.Source);
    end
    if ~isempty(p.Results.Description) && p.Results.Description ~= ""
        M.Attributes.Description = string(p.Results.Description);
    end
    
    % Validate
    bct.schema.manifold.validate(M);
end
