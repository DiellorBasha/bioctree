function attrs = readAttrs(zarrPath, arrayPath)
%READATTRS  Read attributes from Zarr v2 .zattrs file
%
%   attrs = bct.file.zarr.readAttrs(zarrPath, arrayPath)
%
% Purpose
%   Reads JSON attributes from .zattrs file in Zarr store.
%
% Inputs
%   zarrPath  - string, root path to Zarr store (directory)
%   arrayPath - string, relative path to array/group within store
%               (e.g., "manifold/vertices" or "manifold")
%
% Output
%   attrs - struct, attributes parsed from JSON
%           Returns empty struct if .zattrs doesn't exist
%
% Examples
%   vertexAttrs = bct.file.zarr.readAttrs("mesh.zarr", "manifold/vertices");
%   manifoldAttrs = bct.file.zarr.readAttrs("mesh.zarr", "manifold");
%   rootAttrs = bct.file.zarr.readAttrs("mesh.zarr", "");
%
% See also: bct.file.zarr.writeAttrs

arguments
    zarrPath (1,1) string
    arrayPath (1,1) string
end

%% Validate inputs
if ~isfolder(zarrPath)
    error('bct:file:zarr:readAttrs:InvalidPath', ...
        'Zarr store not found: %s', zarrPath);
end

%% Construct .zattrs path
if strlength(arrayPath) == 0
    % Root attributes
    attrsPath = fullfile(zarrPath, '.zattrs');
else
    % Array/group attributes
    fullPath = fullfile(zarrPath, arrayPath);
    if ~isfolder(fullPath)
        error('bct:file:zarr:readAttrs:PathNotFound', ...
            'Path not found: %s', arrayPath);
    end
    attrsPath = fullfile(fullPath, '.zattrs');
end

%% Read and parse JSON
if ~isfile(attrsPath)
    % No attributes - return empty struct
    attrs = struct();
    return;
end

try
    jsonStr = fileread(attrsPath);
    attrs = jsondecode(jsonStr);
catch ME
    error('bct:file:zarr:readAttrs:ParseFailed', ...
        'Failed to parse .zattrs: %s', ME.message);
end

end
