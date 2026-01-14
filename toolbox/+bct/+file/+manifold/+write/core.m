function write(file, core, options)
%CORE  Write core manifold data (vertices, faces, edges)
%
%   bct.file.manifold.write.core(file, core)
%
% Purpose
%   Writes the core manifold mesh data to HDF5 file.
%
% Inputs
%   file - string, HDF5 file path (must exist)
%   core - struct with fields:
%          .vertices - [N×3] vertex coordinates (required)
%          .faces    - [F×3] face indices (required)
%          .edges    - [E×2] edge indices (optional)
%
% Name-Value Arguments
%   Mode       - "overwrite" (default) | "update"
%                "overwrite": replace datasets if they exist
%                "update": only write provided fields
%   Strict     - logical (default true), enforce validation
%   Overwrite  - logical (default true), overwrite existing datasets
%
% Examples
%   % Create file and write core
%   bct.file.create("mesh.h5");
%   core = struct("vertices", V, "faces", F, "edges", E);
%   bct.file.manifold.write.core("mesh.h5", core);
%
%   % Update only vertices
%   core = struct("vertices", V_new);
%   bct.file.manifold.write.core("mesh.h5", core, "Mode", "update");
%
% See also: bct.file.manifold.read.core, bct.file.write

arguments
    file (1,1) string
    core (1,1) struct
    options.Mode (1,1) string {mustBeMember(options.Mode, ["overwrite", "update"])} = "overwrite"
    options.Strict (1,1) logical = true
    options.Overwrite (1,1) logical = true
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:manifold:write:core:FileNotFound', ...
        'File "%s" does not exist. Use bct.file.create first.', file);
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

%% Write datasets
if isfield(core, 'vertices')
    bct.file.write(file, P.vertices, core.vertices, "Overwrite", options.Overwrite);
end

if isfield(core, 'faces')
    bct.file.write(file, P.faces, core.faces, "Overwrite", options.Overwrite);
end

if isfield(core, 'edges') && ~isempty(core.edges)
    bct.file.write(file, P.edges, core.edges, "Overwrite", options.Overwrite);
end

end
