function M = load(data)
%LOAD Load and construct Manifold from various data sources
%
% Syntax:
%   M = bct.manifold.load(filepath)
%   M = bct.manifold.load(meshStruct)
%   M = bct.manifold.load(surfaceMeshObj)
%   M = bct.manifold.load(triangulationObj)
%   M = bct.manifold.load(patchObj)
%
% Supported Input Types:
%   - String/char: File path to .mat file containing mesh data
%   - Struct: Structure with V/Vertices and F/Faces fields
%   - surfaceMesh: MATLAB surfaceMesh object
%   - triangulation: MATLAB triangulation object
%   - Patch: MATLAB graphics patch object
%
% Inputs:
%   data - File path, struct, or geometry object
%
% Outputs:
%   M - bct.Manifold object
%
% File Loading:
%   When data is a file path, the .mat file should contain either:
%   - Variables: V (or Vertices) and F (or Faces)
%   - A struct variable with V/Vertices and F/Faces fields
%
% Examples:
%   % From file
%   M = bct.manifold.load('mesh.mat');
%
%   % From struct
%   meshStruct = struct('V', V, 'F', F);
%   M = bct.manifold.load(meshStruct);
%
%   % From surfaceMesh
%   smesh = surfaceMesh(V, F);
%   M = bct.manifold.load(smesh);
%
%   % From triangulation
%   tri = triangulation(F, V);
%   M = bct.manifold.load(tri);
%
% See also: bct.Manifold, bct.manifold.in

arguments
    data
end

% Dispatch based on input type
if ischar(data) || isstring(data)
    % File path - load from .mat file
    M = loadFromFile(data);
    
elseif isstruct(data)
    % Struct with V/Vertices and F/Faces fields
    M = bct.Manifold(data);
    
elseif isa(data, 'surfaceMesh') || isa(data, 'triangulation') || ...
       isa(data, 'matlab.graphics.primitive.Patch')
    % MATLAB geometry object - use bct.manifold.in
    M = bct.manifold.in(data);
    
else
    error('bct:manifold:UnsupportedInput', ...
        'Unsupported input type: %s. Expected file path, struct, surfaceMesh, triangulation, or Patch.', ...
        class(data));
end

end

% =========================================================================
% Helper Functions
% =========================================================================

function M = loadFromFile(filepath)
%LOADFROMFILE Load mesh from .mat file

% Load file
if ~isfile(filepath)
    error('bct:manifold:FileNotFound', 'File not found: %s', filepath);
end

data = load(filepath);

% Try to extract V/Vertices and F/Faces
V = [];
F = [];

% Check for direct V, F variables
if isfield(data, 'V')
    V = data.V;
elseif isfield(data, 'Vertices')
    V = data.Vertices;
end

if isfield(data, 'F')
    F = data.F;
elseif isfield(data, 'Faces')
    F = data.Faces;
end

% If direct variables found, construct
if ~isempty(V) && ~isempty(F)
    M = bct.Manifold(V, F);
    return;
end

% Otherwise, look for a struct field that contains mesh data
fields = fieldnames(data);
for i = 1:length(fields)
    field = data.(fields{i});
    if isstruct(field) && (isfield(field, 'V') || isfield(field, 'Vertices')) && ...
            (isfield(field, 'F') || isfield(field, 'Faces'))
        M = bct.Manifold(field);
        return;
    end
end

% If we get here, couldn't find valid mesh data
error('bct:manifold:InvalidFileFormat', ...
    'File does not contain valid mesh data (V/Vertices and F/Faces).');
end
