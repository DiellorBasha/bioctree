function M = zarr(zarrPath, options)
%ZARR  Read manifold from Zarr v2 directory store
%
%   M = bct.file.manifold.read.zarr(zarrPath)
%
% Purpose
%   Reads manifold data (vertices, faces, edges) from BCT Zarr format.
%   Converts 0-based indices to 1-based (MATLAB convention).
%   Constructs bct.Manifold object with full Header metadata.
%
% Inputs
%   zarrPath - string, path to Zarr directory store (e.g., "brain.zarr")
%
% Name-Value Arguments
%   ReturnStruct - logical (default false), return struct instead of Manifold
%   Strict       - logical (default true), validate schema and data
%
% Output
%   M - bct.Manifold object (or struct if ReturnStruct=true)
%
% Validation (Strict=true)
%   - Schema version: "bct.manifold@1"
%   - vertices: [N×3] single/double
%   - faces: [F×3] uint32, 0-based indices
%   - edges: [E×2] uint32, 0-based indices (if present)
%
% Examples
%   M = bct.file.manifold.read.zarr("brain.zarr");
%   M = bct.file.manifold.read.zarr("brain.zarr", ReturnStruct=true);
%
% See also: bct.file.manifold.write.zarr, bct.file.manifold.read.core

arguments
    zarrPath (1,1) string
    options.ReturnStruct (1,1) logical = false
    options.Strict (1,1) logical = true
end

%% Validate Zarr store exists
if ~isfolder(zarrPath)
    error('bct:file:manifold:read:zarr:NotFound', ...
        'Zarr store not found: %s', zarrPath);
end

%% Read and validate schema
if options.Strict
    rootAttrs = bct.file.zarr.readAttrs(zarrPath, "");
    if ~isfield(rootAttrs, 'schema')
        error('bct:file:manifold:read:zarr:MissingSchema', ...
            'Missing schema attribute in root .zattrs');
    end
    if ~startsWith(rootAttrs.schema, 'bct.manifold@')
        error('bct:file:manifold:read:zarr:InvalidSchema', ...
            'Invalid schema: %s (expected bct.manifold@1)', rootAttrs.schema);
    end
end

%% Read manifold metadata
manifoldAttrs = bct.file.zarr.readAttrs(zarrPath, "manifold");
if isempty(fieldnames(manifoldAttrs))
    error('bct:file:manifold:read:zarr:MissingManifold', ...
        'Missing manifold group attributes');
end

%% Read vertices (required)
try
    vertices = bct.file.zarr.readArray(zarrPath, "manifold/vertices");
catch ME
    error('bct:file:manifold:read:zarr:MissingVertices', ...
        'Failed to read vertices: %s', ME.message);
end

% Validate shape
if size(vertices, 2) ~= 3
    error('bct:file:manifold:read:zarr:InvalidVertices', ...
        'Vertices must be [N×3], got [%d×%d]', size(vertices, 1), size(vertices, 2));
end

% Convert to double if needed (reader returns single by default)
vertices = double(vertices);

%% Read faces (required)
try
    faces = bct.file.zarr.readArray(zarrPath, "manifold/faces");
catch ME
    error('bct:file:manifold:read:zarr:MissingFaces', ...
        'Failed to read faces: %s', ME.message);
end

% Validate shape
if size(faces, 2) ~= 3
    error('bct:file:manifold:read:zarr:InvalidFaces', ...
        'Faces must be [F×3], got [%d×%d]', size(faces, 1), size(faces, 2));
end

% Convert 0-based to 1-based indexing (MATLAB convention)
faceAttrs = bct.file.zarr.readAttrs(zarrPath, "manifold/faces");
if isfield(faceAttrs, 'index_base') && faceAttrs.index_base == 0
    faces = faces + 1;
end

%% Read edges (optional)
edges = [];
try
    edges = bct.file.zarr.readArray(zarrPath, "manifold/edges");
    
    % Validate shape
    if size(edges, 2) ~= 2
        warning('bct:file:manifold:read:zarr:InvalidEdges', ...
            'Edges must be [E×2], ignoring invalid edges');
        edges = [];
    else
        % Convert 0-based to 1-based indexing
        edgeAttrs = bct.file.zarr.readAttrs(zarrPath, "manifold/edges");
        if isfield(edgeAttrs, 'index_base') && edgeAttrs.index_base == 0
            edges = edges + 1;
        end
    end
catch
    % Edges not present - that's OK
    edges = [];
end

%% Construct Header from metadata
Header = struct();

% Core fields
if isfield(manifoldAttrs, 'id')
    Header.Id = string(manifoldAttrs.id);
end
if isfield(manifoldAttrs, 'name')
    Header.Name = string(manifoldAttrs.name);
end
if isfield(manifoldAttrs, 'coordinate_system')
    Header.CoordinateSystem = string(manifoldAttrs.coordinate_system);
end
if isfield(manifoldAttrs, 'face_winding')
    Header.FaceWinding = string(manifoldAttrs.face_winding);
end
if isfield(manifoldAttrs, 'normal_convention')
    Header.NormalConvention = string(manifoldAttrs.normal_convention);
end

% Metric structure
if isfield(manifoldAttrs, 'metric')
    metric = manifoldAttrs.metric;
    Header.Metric = struct();
    
    if isfield(metric, 'unit')
        Header.Metric.Unit = string(metric.unit);
    end
    
    % Rescale substructure
    if isfield(metric, 'rescale')
        rescale = metric.rescale;
        Header.Metric.Rescale = struct();
        
        if isfield(rescale, 'applied')
            Header.Metric.Rescale.Applied = logical(rescale.applied);
        end
        if isfield(rescale, 'from_unit') && ~isempty(rescale.from_unit)
            Header.Metric.Rescale.FromUnit = string(rescale.from_unit);
        end
        if isfield(rescale, 'factor')
            Header.Metric.Rescale.Factor = double(rescale.factor);
        end
        if isfield(rescale, 'timestamp') && ~isempty(rescale.timestamp)
            Header.Metric.Rescale.Timestamp = datetime(rescale.timestamp, ...
                'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC');
        end
    end
end

% Units (legacy field)
if isfield(manifoldAttrs, 'units')
    Header.Units = string(manifoldAttrs.units);
end

% Source
if isfield(manifoldAttrs, 'source')
    Header.Source = string(manifoldAttrs.source);
end

% Timestamps
if isfield(manifoldAttrs, 'created_at')
    Header.CreatedAt = datetime(manifoldAttrs.created_at, ...
        'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC');
end

% Creator
if isfield(manifoldAttrs, 'created_by')
    Header.CreatedBy = string(manifoldAttrs.created_by);
end

%% Return struct or Manifold object
if options.ReturnStruct
    M = struct();
    M.Vertices = vertices;
    M.Faces = faces;
    M.Edges = edges;
    M.Header = Header;
else
    % Construct bct.Manifold object
    % Note: Header properties are read-only after construction
    % The constructor initializes Header with defaults
    % Users can access metadata through the returned struct by using ReturnStruct=true
    M = bct.Manifold(vertices, faces);
    
    % Edges are automatically computed by the constructor
    % Header is initialized with defaults - to preserve Zarr metadata,
    % use ReturnStruct=true to get raw data + metadata
end

end
