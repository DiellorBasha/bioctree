function spec = topology()
%TOPOLOGY Return canonical schema specification for BCT topology structure
%
% Syntax:
%   spec = bct.schema.topology()
%
% Description:
%   Defines the authoritative schema for topology structures in BCT.
%   A topology structure contains:
%     - .attributes: Group-level metadata (extends bct.schema.group)
%     - Topology datasets: edges, adjacency, edgeFaces, boundaryEdges, etc.
%
%   This schema is used by bct.manifold.topology() and related functions
%   to ensure consistency in topology representation across BCT.
%
% Outputs:
%   spec - Structure with fields:
%     .name        - Schema name
%     .version     - Schema version string
%     .description - Human-readable description
%     .attributes  - Group attributes specification
%     .datasets    - Dataset specifications
%     .validation  - Validation function handles
%
% Topology Structure:
%   topo = struct(...
%       'attributes', struct(...
%           'path', '/topology', ...
%           'schema', 'bct.manifold.topology@1.0.0', ...
%           'package', 'bct.manifold.topology', ...
%           'numVertices', N, ...
%           'numEdges', E, ...
%           'numFaces', F, ...
%           'isClosed', true, ...
%           'eulerCharacteristic', 2), ...
%       'edges', dataset, ...
%       'adjacency', dataset, ...
%       'edgeFaces', dataset, ...
%       'boundaryEdges', dataset, ...
%       'degree', dataset)
%
% Examples:
%   % Get topology schema
%   spec = bct.schema.topology();
%
%   % Validate topology structure
%   M = bct.Manifold(V, F);
%   topo = bct.manifold.topology(M);
%   isValid = bct.schema.topology.validate(topo);
%
% See also: bct.manifold.topology, bct.schema.group, bct.schema.dataset

% Schema metadata
spec.name = "bct.topology";
spec.version = "1.0.0";
spec.description = "Schema for topology structures (manifold combinatorial properties)";
spec.package = "bct.schema";

%% Group Attributes (extends bct.schema.group)
spec.attributes = struct();

% Base fields (from bct.schema.group)
spec.attributes.base = struct(...
    'path', '/topology', ...
    'schema', 'bct.manifold.topology@1.0.0', ...
    'package', 'bct.manifold.topology');

% Topology-specific required fields
spec.attributes.required = struct();

spec.attributes.required.numVertices = struct(...
    'type', 'numeric', ...
    'description', 'Number of vertices in manifold', ...
    'validate', @(x) isnumeric(x) && isscalar(x) && x > 0);

spec.attributes.required.numEdges = struct(...
    'type', 'numeric', ...
    'description', 'Number of edges in manifold', ...
    'validate', @(x) isnumeric(x) && isscalar(x) && x > 0);

spec.attributes.required.numFaces = struct(...
    'type', 'numeric', ...
    'description', 'Number of faces in manifold', ...
    'validate', @(x) isnumeric(x) && isscalar(x) && x > 0);

% Topology-specific optional fields
spec.attributes.optional = struct();

spec.attributes.optional.isClosed = struct(...
    'type', 'logical', ...
    'description', 'Whether manifold has no boundary edges', ...
    'default', []);

spec.attributes.optional.eulerCharacteristic = struct(...
    'type', 'numeric', ...
    'description', 'Euler characteristic (V - E + F)', ...
    'default', []);

spec.attributes.optional.genus = struct(...
    'type', 'numeric', ...
    'description', 'Topological genus (for closed surfaces)', ...
    'default', []);

%% Dataset Specifications

spec.datasets.edges = struct(...
    'name', 'edges', ...
    'path', '/topology/edges', ...
    'description', 'Edge connectivity list (unique undirected edges)', ...
    'shape', @(nE) [nE, 2], ...
    'dtype', 'uint32', ...
    'support', 'edge', ...
    'units', '1');

spec.datasets.adjacency = struct(...
    'name', 'adjacency', ...
    'path', '/topology/adjacency', ...
    'description', 'Vertex adjacency matrix (sparse, symmetric, no self-loops)', ...
    'shape', @(nV) [nV, nV], ...
    'dtype', 'logical', ...
    'support', 'vertex', ...
    'units', '1');

spec.datasets.edgeFaces = struct(...
    'name', 'edgeFaces', ...
    'path', '/topology/edgeFaces', ...
    'description', 'Face indices adjacent to each edge (2 for interior, 1 for boundary)', ...
    'shape', @(nE) [nE, 2], ...
    'dtype', 'uint32', ...
    'support', 'edge', ...
    'units', '1');

spec.datasets.boundaryEdges = struct(...
    'name', 'boundaryEdges', ...
    'path', '/topology/boundaryEdges', ...
    'description', 'Indices of boundary edges', ...
    'shape', @(nB) [nB, 1], ...
    'dtype', 'uint32', ...
    'support', 'edge', ...
    'units', '1');

spec.datasets.degree = struct(...
    'name', 'degree', ...
    'path', '/topology/degree', ...
    'description', 'Vertex degree (number of incident edges)', ...
    'shape', @(nV) [nV, 1], ...
    'dtype', 'double', ...
    'support', 'vertex', ...
    'units', '1');

%% Structure Specification
spec.structure = struct();
spec.structure.required = ["attributes", "edges", "adjacency"];
spec.structure.optional = ["edgeFaces", "boundaryEdges", "degree"];
spec.structure.description = 'Topology structure must have attributes, edges, and adjacency';

%% Validation
spec.validate = @validateTopology;

%% Helper Functions
spec.make = @makeTopology;

%% Documentation
spec.documentation = struct(...
    'purpose', 'Enforce uniform topology structure across BCT', ...
    'usage', 'All topology computations should return this structure', ...
    'examples', struct(...
        'compute', 'topo = bct.manifold.topology(M)', ...
        'validate', 'bct.schema.topology.validate(topo)', ...
        'access', 'edges = topo.edges.value; A = topo.adjacency.value'));

end

%% =================================================================
%% VALIDATION FUNCTIONS
%% =================================================================

function isValid = validateTopology(topo, varargin)
    %VALIDATETOPOLOGY Validate complete topology structure
    %
    % Inputs:
    %   topo - Topology structure to validate
    %
    % Name-Value Arguments:
    %   Strict - true (default) to throw errors, false to return report
    %
    % Outputs:
    %   isValid - true if valid, false otherwise
    
    p = inputParser;
    p.addRequired('topo');
    p.addParameter('Strict', true, @islogical);
    p.parse(topo, varargin{:});
    
    strict = p.Results.Strict;
    
    try
        % Get schema
        spec = bct.schema.topology();
        
        %% Check required fields
        if ~isstruct(topo)
            error('bct:schema:topology:NotStruct', 'Topology must be a struct');
        end
        
        requiredFields = spec.structure.required;
        for i = 1:numel(requiredFields)
            field = requiredFields(i);
            if ~isfield(topo, field)
                error('bct:schema:topology:MissingField', ...
                    'Required field missing: %s', field);
            end
        end
        
        %% Validate group attributes
        attrs = topo.attributes;
        
        % Validate base group fields
        bct.schema.group.validate(attrs);
        
        % Validate topology-specific required fields
        requiredAttrs = fieldnames(spec.attributes.required);
        for i = 1:numel(requiredAttrs)
            fieldName = requiredAttrs{i};
            if ~isfield(attrs, fieldName)
                error('bct:schema:topology:MissingAttribute', ...
                    'Required attribute missing: %s', fieldName);
            end
            
            % Validate field
            fieldSpec = spec.attributes.required.(fieldName);
            value = attrs.(fieldName);
            
            % Type check
            if isfield(fieldSpec, 'type')
                switch fieldSpec.type
                    case 'numeric'
                        if ~isnumeric(value)
                            error('bct:schema:topology:InvalidType', ...
                                'Attribute %s must be numeric', fieldName);
                        end
                    case 'logical'
                        if ~islogical(value)
                            error('bct:schema:topology:InvalidType', ...
                                'Attribute %s must be logical', fieldName);
                        end
                end
            end
            
            % Custom validation
            if isfield(fieldSpec, 'validate') && isa(fieldSpec.validate, 'function_handle')
                fieldSpec.validate(value);
            end
        end
        
        % Validate optional fields if present
        optionalAttrs = fieldnames(spec.attributes.optional);
        for i = 1:numel(optionalAttrs)
            fieldName = optionalAttrs{i};
            if isfield(attrs, fieldName)
                fieldSpec = spec.attributes.optional.(fieldName);
                value = attrs.(fieldName);
                
                % Type check
                if isfield(fieldSpec, 'type')
                    switch fieldSpec.type
                        case 'numeric'
                            if ~isnumeric(value) && ~isempty(value)
                                error('bct:schema:topology:InvalidType', ...
                                    'Attribute %s must be numeric', fieldName);
                            end
                        case 'logical'
                            if ~islogical(value) && ~isempty(value)
                                error('bct:schema:topology:InvalidType', ...
                                    'Attribute %s must be logical', fieldName);
                            end
                    end
                end
            end
        end
        
        %% Validate datasets
        % Required datasets
        for i = 1:numel(requiredFields)
            field = requiredFields(i);
            if field == "attributes"
                continue;
            end
            
            dataset = topo.(field);
            bct.schema.dataset.validate(dataset);
        end
        
        % Optional datasets
        optionalFields = spec.structure.optional;
        for i = 1:numel(optionalFields)
            field = optionalFields(i);
            if isfield(topo, field)
                dataset = topo.(field);
                bct.schema.dataset.validate(dataset);
            end
        end
        
        %% Cross-validate dimensions
        nV_attrs = double(attrs.numVertices);
        nE_attrs = double(attrs.numEdges);
        nF_attrs = double(attrs.numFaces);
        
        % Check edges dimensions
        [nE_data, nCols] = size(topo.edges.value);
        if nE_attrs ~= nE_data
            error('bct:schema:topology:DimensionMismatch', ...
                'numEdges (%d) does not match edges size (%d)', nE_attrs, nE_data);
        end
        if nCols ~= 2
            error('bct:schema:topology:InvalidShape', ...
                'Edges must have 2 columns, got %d', nCols);
        end
        
        % Check adjacency dimensions
        [nV_adj_rows, nV_adj_cols] = size(topo.adjacency.value);
        if nV_attrs ~= nV_adj_rows || nV_attrs ~= nV_adj_cols
            error('bct:schema:topology:DimensionMismatch', ...
                'numVertices (%d) does not match adjacency size (%d×%d)', ...
                nV_attrs, nV_adj_rows, nV_adj_cols);
        end
        
        %% Validation passed
        isValid = true;
        
    catch ME
        if strict
            rethrow(ME);
        end
        warning('bct:schema:topology:ValidationFailed', ...
            'Topology validation failed: %s', ME.message);
        isValid = false;
    end
end

function topo = makeTopology(M, varargin)
    %MAKETOPOLOGY Create schema-compliant topology structure
    %
    % Syntax:
    %   topo = bct.schema.topology.make(M)
    %
    % Inputs:
    %   M - bct.Manifold object
    %
    % Examples:
    %   M = bct.Manifold(V, F);
    %   topo = bct.schema.topology.make(M);
    
    p = inputParser;
    p.addRequired('M', @(x) isa(x, 'bct.Manifold'));
    p.parse(M, varargin{:});
    
    % Use the actual topology computation function
    topo = bct.manifold.topology(M);
    
    % Validate
    bct.schema.topology.validate(topo);
end
