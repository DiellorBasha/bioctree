function core = read(file, options)
%CORE  Read core manifold data (vertices, faces, edges)
%
%   core = bct.file.manifold.read.core(file)
%
% Purpose
%   Reads the core manifold mesh data: vertices, faces, and edges (if present).
%
% Inputs
%   file - string, HDF5 file path
%
% Name-Value Arguments
%   Strict - logical (default true), enforce validation
%
% Output
%   core - struct with fields:
%          .vertices - [N×3] vertex coordinates
%          .faces    - [F×3] face indices
%          .edges    - [E×2] edge indices (or [] if not present)
%
% Validation (Strict=true)
%   - vertices must be [N×3]
%   - faces must be [F×3]
%   - edges must be [E×2] if present
%
% Examples
%   core = bct.file.manifold.read.core("mesh.h5");
%   V = core.vertices;
%   F = core.faces;
%
% See also: bct.file.manifold.write.core, bct.file.read.manifold

arguments
    file (1,1) string
    options.Strict (1,1) logical = true
end

%% Get canonical paths
P = bct.file.manifold.paths();

%% Read core datasets
core = struct();

% Read vertices (required)
if ~bct.file.exists(file, P.vertices)
    error('bct:file:manifold:read:core:MissingVertices', ...
        'Required dataset "%s" not found.', P.vertices);
end
core.vertices = bct.file.read(file, P.vertices);

% Read faces (required)
if ~bct.file.exists(file, P.faces)
    error('bct:file:manifold:read:core:MissingFaces', ...
        'Required dataset "%s" not found.', P.faces);
end
core.faces = bct.file.read(file, P.faces);

% Read edges (optional)
if bct.file.exists(file, P.edges)
    core.edges = bct.file.read(file, P.edges);
else
    core.edges = [];
end

%% Validation
if options.Strict
    % Validate vertices shape
    [nV, dV] = size(core.vertices);
    if dV ~= 3
        error('bct:file:manifold:read:core:InvalidVertices', ...
            'Vertices must be [N×3], got [%d×%d].', nV, dV);
    end
    
    % Validate faces shape
    [nF, dF] = size(core.faces);
    if dF ~= 3
        error('bct:file:manifold:read:core:InvalidFaces', ...
            'Faces must be [F×3], got [%d×%d].', nF, dF);
    end
    
    % Validate edges shape if present
    if ~isempty(core.edges)
        [nE, dE] = size(core.edges);
        if dE ~= 2
            error('bct:file:manifold:read:core:InvalidEdges', ...
                'Edges must be [E×2], got [%d×%d].', nE, dE);
        end
    end
end

end
