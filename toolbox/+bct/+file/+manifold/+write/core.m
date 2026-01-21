function write(file, core, options)
%CORE  Write core manifold data (vertices, faces, edges) and Header metadata
%
%   bct.file.manifold.write.core(file, core)
%   bct.file.manifold.write.core(file, M)  % M is bct.Manifold
%
% Purpose
%   Writes the core manifold mesh data and Header metadata to HDF5 file.
%   Supports both struct input (backward compatible) and bct.Manifold objects.
%
% Inputs
%   file - string, HDF5 file path (must exist)
%   core - struct with fields:
%          .vertices - [N×3] vertex coordinates (required)
%          .faces    - [F×3] face indices (required)
%          .edges    - [E×2] edge indices (optional)
%          OR bct.Manifold object (extracts mesh + Header)
%
% Name-Value Arguments
%   Mode       - "overwrite" (default) | "update"
%                "overwrite": replace datasets if they exist
%                "update": only write provided fields
%   Strict     - logical (default true), enforce validation
%   Overwrite  - logical (default true), overwrite existing datasets
%   Header     - struct (optional), Header metadata to write as /manifold attributes
%                If core is bct.Manifold, Header is extracted automatically
%
% Examples
%   % Write Manifold directly (recommended)
%   M = bct.Manifold.read("bunny.obj");
%   bct.file.create("mesh.h5");
%   bct.file.manifold.write.core("mesh.h5", M);
%
%   % Write struct (backward compatible)
%   core = struct("vertices", V, "faces", F, "edges", E);
%   bct.file.manifold.write.core("mesh.h5", core);
%
%   % Write struct with Header
%   bct.file.manifold.write.core("mesh.h5", core, "Header", M.Header);
%
% See also: bct.file.manifold.read.core, bct.file.write

arguments
    file (1,1) string
    core  % struct or bct.Manifold
    options.Mode (1,1) string {mustBeMember(options.Mode, ["overwrite", "update"])} = "overwrite"
    options.Strict (1,1) logical = true
    options.Overwrite (1,1) logical = true
    options.Header (1,1) struct = struct()
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:manifold:write:core:FileNotFound', ...
        'File "%s" does not exist. Use bct.file.create first.', file);
end

%% Extract data from Manifold or struct
Header = options.Header;
if isa(core, 'bct.Manifold')
    % Extract mesh data and Header from Manifold
    M = core;
    core = struct();
    core.vertices = M.Vertices;
    core.faces = M.Faces;
    core.edges = M.Edges;
    Header = M.Header;
elseif ~isstruct(core)
    error('bct:file:manifold:write:core:InvalidInput', ...
        'core must be a struct or bct.Manifold object.');
end

%% Get canonical paths
P = bct.file.manifold.paths();

%% Validate core struct
requiredFields = ["vertices", "faces"];
if strcmp(options.Mode, "overwrite")
    for field = requiredFields
        if ~isfield(core, field)
            error('bct:file:manifold:write:core:MissingField', ...
                'Required field "%s" missing from core struct.', field);
        end
    end
end

%% Validation (Strict mode)
if options.Strict
    if isfield(core, 'vertices')
        [~, dV] = size(core.vertices);
        if dV ~= 3
            error('bct:file:manifold:write:core:InvalidVertices', ...
                'Vertices must be [N×3], got [%d×%d].', size(core.vertices));
        end
    end
    
    if isfield(core, 'faces')
        [~, dF] = size(core.faces);
        if dF ~= 3
            error('bct:file:manifold:write:core:InvalidFaces', ...
                'Faces must be [F×3], got [%d×%d].', size(core.faces));
        end
    end
    
    if isfield(core, 'edges') && ~isempty(core.edges)
        [~, dE] = size(core.edges);
        if dE ~= 2
            error('bct:file:manifold:write:core:InvalidEdges', ...
                'Edges must be [E×2], got [%d×%d].', size(core.edges));
        end
    end
end

%% Write datasets with 0-based indexing for interchange
% Export policy: Convert to 0-based indices for downstream consumption (Three.js, Python)
% Internal MATLAB remains 1-based

if isfield(core, 'vertices')
    % Vertices: write as-is with dataset attributes
    bct.file.write(file, P.vertices, core.vertices, "Overwrite", options.Overwrite);
    % Add dataset-level attributes
    bct.file.h5.writeAttribute(file, P.vertices, 'axis', '["vertex","xyz"]');
    bct.file.h5.writeAttribute(file, P.vertices, 'dtype_target', 'float32');
    if isfield(Header, 'Units') && ~isempty(Header.Units)
        bct.file.h5.writeAttribute(file, P.vertices, 'units', char(Header.Units));
    end
end

if isfield(core, 'faces')
    % Faces: convert to 0-based for export
    faces0based = core.faces - 1;  % MATLAB 1-based → 0-based
    bct.file.write(file, P.faces, faces0based, "Overwrite", options.Overwrite);
    % Add dataset-level attributes
    bct.file.h5.writeAttribute(file, P.faces, 'axis', '["face","corner"]');
    bct.file.h5.writeAttribute(file, P.faces, 'index_base', int32(0));
    bct.file.h5.writeAttribute(file, P.faces, 'primitive', 'triangles');
end

if isfield(core, 'edges') && ~isempty(core.edges)
    % Edges: convert to 0-based for export
    edges0based = core.edges - 1;  % MATLAB 1-based → 0-based
    bct.file.write(file, P.edges, edges0based, "Overwrite", options.Overwrite);
    % Add dataset-level attributes
    bct.file.h5.writeAttribute(file, P.edges, 'axis', '["edge","endpoint"]');
    bct.file.h5.writeAttribute(file, P.edges, 'index_base', int32(0));
    bct.file.h5.writeAttribute(file, P.edges, 'directed', int32(0));  % 0=false, 1=true
    bct.file.h5.writeAttribute(file, P.edges, 'canonical', 'sorted_unique');
end

%% Write Header metadata as /manifold group attributes
if ~isempty(fieldnames(Header))
    writeHeaderAttributes(file, Header);
end

end

%% ========================================================================
%% HELPER: Write Header as /manifold attributes
%% ========================================================================
function writeHeaderAttributes(file, Header)
%WRITEHEADERATTRIBUTES  Write Header struct as /manifold group attributes
%
% Maps bct.Manifold.Header fields to HDF5 attributes following schema:
%   Header.ID              → id
%   Header.Name            → name
%   Header.CoordinateSystem → coordinate_system
%   Header.FaceWinding     → face_winding
%   Header.NormalConvention → normal_convention
%   Header.Metric          → flattened to metric.unit, metric.rescale.*
%   Header.Units           → units (for convenience)
%   Header.Source          → source
%   Header.CreatedAt       → created_at
%   Header.CreatedBy       → created_by
%   Header.IndexBase       → matlab_index_base (internal convention)
%
% Also writes:
%   schema = "bct.manifold@1"
%   index_base_faces = 0 (export convention)
%   index_base_edges = 0 (export convention)
%
% Export Policy:
%   - Internal: IndexBase=1 (MATLAB), faces/edges use 1-based indexing
%   - Export: index_base=0, faces/edges converted to 0-based for downstream

% Schema version
bct.file.h5.writeAttribute(file, '/manifold', 'schema', 'bct.manifold@1');

% Export index base policy: 0-based for interchange
bct.file.h5.writeAttribute(file, '/manifold', 'index_base_faces', int32(0));
bct.file.h5.writeAttribute(file, '/manifold', 'index_base_edges', int32(0));

% ID (identifier)
if isfield(Header, 'ID') && ~isempty(Header.ID) && strlength(Header.ID) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'id', char(Header.ID));
end

% Name (human-readable)
if isfield(Header, 'Name') && ~isempty(Header.Name) && strlength(Header.Name) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'name', char(Header.Name));
end

% Coordinate system (RAS, LPS, etc.)
if isfield(Header, 'CoordinateSystem') && ~isempty(Header.CoordinateSystem) && strlength(Header.CoordinateSystem) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'coordinate_system', char(Header.CoordinateSystem));
end

% Face winding (CCW, CW)
if isfield(Header, 'FaceWinding') && ~isempty(Header.FaceWinding) && strlength(Header.FaceWinding) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'face_winding', char(Header.FaceWinding));
end

% Normal convention (right-hand-rule, left-hand-rule)
if isfield(Header, 'NormalConvention') && ~isempty(Header.NormalConvention) && strlength(Header.NormalConvention) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'normal_convention', char(Header.NormalConvention));
end

% Units (m, mm, etc.) - top-level convenience attribute
if isfield(Header, 'Units') && ~isempty(Header.Units) && strlength(Header.Units) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'units', char(Header.Units));
end

% Metric (flattened) - portable across HDF5 and Zarr
if isfield(Header, 'Metric') && ~isempty(Header.Metric)
    M = Header.Metric;
    % metric.unit
    if isfield(M, 'unit') && ~isempty(M.unit)
        bct.file.h5.writeAttribute(file, '/manifold', 'metric.unit', char(M.unit));
    end
    % metric.rescale.applied
    if isfield(M, 'rescale') && isfield(M.rescale, 'applied')
        bct.file.h5.writeAttribute(file, '/manifold', 'metric.rescale.applied', int32(M.rescale.applied));
    end
    % metric.rescale.fromUnit
    if isfield(M, 'rescale') && isfield(M.rescale, 'fromUnit') && ~isempty(M.rescale.fromUnit)
        bct.file.h5.writeAttribute(file, '/manifold', 'metric.rescale.from_unit', char(M.rescale.fromUnit));
    end
    % metric.rescale.factor
    if isfield(M, 'rescale') && isfield(M.rescale, 'factor')
        bct.file.h5.writeAttribute(file, '/manifold', 'metric.rescale.factor', double(M.rescale.factor));
    end
    % metric.rescale.timestamp
    if isfield(M, 'rescale') && isfield(M.rescale, 'timestamp') && ~isempty(M.rescale.timestamp)
        bct.file.h5.writeAttribute(file, '/manifold', 'metric.rescale.timestamp', char(M.rescale.timestamp));
    end
end

% IndexBase (internal MATLAB convention) - optional metadata
if isfield(Header, 'IndexBase') && ~isempty(Header.IndexBase)
    bct.file.h5.writeAttribute(file, '/manifold', 'matlab_index_base', int32(Header.IndexBase));
end

% Source (file path)
if isfield(Header, 'Source') && ~isempty(Header.Source) && strlength(Header.Source) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'source', char(Header.Source));
end

% Created at (timestamp) - convert datetime to ISO8601 string
if isfield(Header, 'CreatedAt') && ~isempty(Header.CreatedAt)
    if isa(Header.CreatedAt, 'datetime')
        createdAtStr = char(datetime(Header.CreatedAt, 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    else
        createdAtStr = char(Header.CreatedAt);
    end
    bct.file.h5.writeAttribute(file, '/manifold', 'created_at', createdAtStr);
end

% Created by (user/system)
if isfield(Header, 'CreatedBy') && ~isempty(Header.CreatedBy) && strlength(Header.CreatedBy) > 0
    bct.file.h5.writeAttribute(file, '/manifold', 'created_by', char(Header.CreatedBy));
end

end
