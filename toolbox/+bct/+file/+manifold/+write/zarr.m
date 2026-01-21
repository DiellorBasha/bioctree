function write(zarrPath, core, options)
%ZARR  Write core manifold data (vertices, faces, edges) and Header to Zarr
%
%   bct.file.manifold.write.zarr(zarrPath, core)
%   bct.file.manifold.write.zarr(zarrPath, M)  % M is bct.Manifold
%
% Purpose
%   Writes core manifold mesh data and Header metadata to Zarr directory.
%   Supports both struct input (backward compatible) and bct.Manifold objects.
%   Exports with 0-based indexing for Three.js/Python consumption.
%
% Inputs
%   zarrPath - string, Zarr directory path (e.g., "bunny.zarr")
%   core     - struct with fields:
%              .vertices - [N×3] vertex coordinates (required)
%              .faces    - [F×3] face indices (required)
%              .edges    - [E×2] edge indices (optional)
%              OR bct.Manifold object (extracts mesh + Header)
%
% Name-Value Arguments
%   Mode       - "overwrite" (default) | "update"
%                "overwrite": replace datasets if they exist
%                "update": only write provided fields
%   Strict     - logical (default true), enforce validation
%   Overwrite  - logical (default true), overwrite existing datasets
%   Header     - struct (optional), Header metadata to write as group attributes
%                If core is bct.Manifold, Header is extracted automatically
%
% Directory Structure
%   bunny.zarr/
%     .zgroup
%     .zattrs (root attributes: created_utc, schema)
%     manifold/
%       .zgroup
%       .zattrs (Header attributes)
%       vertices/
%         .zarray
%         .zattrs (axis, dtype_target, units)
%         0.0.0 (chunk files)
%       faces/
%         .zarray
%         .zattrs (axis, index_base, primitive)
%         0.0 (chunk files)
%       edges/
%         .zarray
%         .zattrs (axis, index_base, directed, canonical)
%         0.0 (chunk files)
%
% Examples
%   % Write Manifold directly (recommended)
%   M = bct.Manifold.read("bunny.obj");
%   bct.file.manifold.write.zarr("bunny.zarr", M);
%
%   % Write struct (backward compatible)
%   core = struct("vertices", V, "faces", F, "edges", E);
%   bct.file.manifold.write.zarr("bunny.zarr", core);
%
%   % Write struct with Header
%   bct.file.manifold.write.zarr("bunny.zarr", core, "Header", M.Header);
%
% See also: bct.file.manifold.write.core, bct.file.zarr.writeArray

arguments
    zarrPath (1,1) string
    core  % struct or bct.Manifold
    options.Mode (1,1) string {mustBeMember(options.Mode, ["overwrite", "update"])} = "overwrite"
    options.Strict (1,1) logical = true
    options.Overwrite (1,1) logical = true
    options.Header (1,1) struct = struct()
end

%% Handle existing directory
if isfolder(zarrPath)
    if strcmp(options.Mode, "overwrite") && options.Overwrite
        % Remove existing store
        rmdir(zarrPath, 's');
    elseif ~strcmp(options.Mode, "update")
        error('bct:file:manifold:write:zarr:PathExists', ...
            'Zarr store "%s" already exists. Use Mode="update" or Overwrite=true.', zarrPath);
    end
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
    error('bct:file:manifold:write:zarr:InvalidInput', ...
        'core must be a struct or bct.Manifold object.');
end

%% Validate core struct
requiredFields = ["vertices", "faces"];
if strcmp(options.Mode, "overwrite")
    for field = requiredFields
        if ~isfield(core, field)
            error('bct:file:manifold:write:zarr:MissingField', ...
                'Required field "%s" missing from core struct.', field);
        end
    end
end

%% Validation (Strict mode)
if options.Strict
    if isfield(core, 'vertices')
        [~, dV] = size(core.vertices);
        if dV ~= 3
            error('bct:file:manifold:write:zarr:InvalidVertices', ...
                'Vertices must be [N×3], got [%d×%d].', size(core.vertices));
        end
    end
    
    if isfield(core, 'faces')
        [~, dF] = size(core.faces);
        if dF ~= 3
            error('bct:file:manifold:write:zarr:InvalidFaces', ...
                'Faces must be [F×3], got [%d×%d].', size(core.faces));
        end
    end
    
    if isfield(core, 'edges') && ~isempty(core.edges)
        [~, dE] = size(core.edges);
        if dE ~= 2
            error('bct:file:manifold:write:zarr:InvalidEdges', ...
                'Edges must be [E×2], got [%d×%d].', size(core.edges));
        end
    end
end

%% Create root Zarr store
bct.file.zarr.createGroup(zarrPath, "");

% Write root attributes
rootAttrs = struct();
rootAttrs.schema = 'bct.manifold@1';  % Consistent schema across HDF5 and Zarr
rootAttrs.format = 'zarr';            % Indicate Zarr format
rootAttrs.created_utc = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
bct.file.zarr.writeAttrs(zarrPath, "", rootAttrs);

%% Create /manifold group
bct.file.zarr.createGroup(zarrPath, "manifold");

%% Convert indices to 0-based for export
if isfield(core, 'faces') && isfield(core, 'edges')
    [faces0based, edges0based] = bct.file.manifold.prepare.convertIndices(core.faces, core.edges);
elseif isfield(core, 'faces')
    faces0based = core.faces - 1;
    edges0based = [];
else
    faces0based = [];
    edges0based = [];
end

%% Write datasets with 0-based indexing and dataset attributes

if isfield(core, 'vertices')
    % Vertices: write as float32 for GPU efficiency
    bct.file.zarr.writeArray(zarrPath, "manifold/vertices", single(core.vertices), ...
        Datatype="single", Overwrite=options.Overwrite);
    
    % Dataset-level attributes
    vertexAttrs = struct();
    vertexAttrs.axis = ["vertex", "xyz"];
    vertexAttrs.dtype_target = 'float32';
    if isfield(Header, 'Units') && ~isempty(Header.Units)
        vertexAttrs.units = char(Header.Units);
    end
    bct.file.zarr.writeAttrs(zarrPath, "manifold/vertices", vertexAttrs);
end

if isfield(core, 'faces')
    % Faces: write 0-based as uint32
    bct.file.zarr.writeArray(zarrPath, "manifold/faces", faces0based, ...
        Datatype="uint32", Overwrite=options.Overwrite);
    
    % Dataset-level attributes
    faceAttrs = struct();
    faceAttrs.axis = ["face", "corner"];
    faceAttrs.index_base = int32(0);
    faceAttrs.primitive = 'triangles';
    bct.file.zarr.writeAttrs(zarrPath, "manifold/faces", faceAttrs);
end

if isfield(core, 'edges') && ~isempty(core.edges)
    % Edges: write 0-based as uint32
    bct.file.zarr.writeArray(zarrPath, "manifold/edges", edges0based, ...
        Datatype="uint32", Overwrite=options.Overwrite);
    
    % Dataset-level attributes
    edgeAttrs = struct();
    edgeAttrs.axis = ["edge", "endpoint"];
    edgeAttrs.index_base = int32(0);
    edgeAttrs.directed = false;
    edgeAttrs.canonical = 'sorted_unique';
    bct.file.zarr.writeAttrs(zarrPath, "manifold/edges", edgeAttrs);
end

%% Write Header metadata as /manifold group attributes
if ~isempty(fieldnames(Header))
    manifoldAttrs = bct.file.manifold.prepare.mapHeader(Header);
    bct.file.zarr.writeAttrs(zarrPath, "manifold", manifoldAttrs);
end

end
