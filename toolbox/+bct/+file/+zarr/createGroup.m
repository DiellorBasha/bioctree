function createGroup(zarrPath, groupPath)
%BCT.FILE.ZARR.CREATEGROUP  Create Zarr group with .zgroup metadata
%
%   bct.file.zarr.createGroup(zarrPath, groupPath)
%
% Purpose
%   Creates a Zarr group directory with .zgroup metadata file.
%   Recursively creates parent groups if needed.
%
% Inputs
%   zarrPath  - string, root Zarr directory (e.g., "bunny.zarr")
%   groupPath - string, group path relative to zarrPath (e.g., "manifold/geometry")
%
% Examples
%   % Create single group
%   bct.file.zarr.createGroup("mesh.zarr", "manifold");
%
%   % Create nested groups (creates all parents)
%   bct.file.zarr.createGroup("mesh.zarr", "manifold/geometry/normals");
%
% See also: bct.file.zarr.writeArray, bct.file.zarr.writeAttrs

arguments
    zarrPath (1,1) string
    groupPath (1,1) string
end

%% Normalize paths
if strlength(groupPath) == 0
    % Root group
    fullPath = zarrPath;
    parts = string.empty;
else
    fullPath = fullfile(zarrPath, groupPath);
    % Split into components
    parts = split(groupPath, '/');
    parts = parts(strlength(parts) > 0);
end

%% Create root if needed
if ~isfolder(zarrPath)
    mkdir(zarrPath);
end

% Always ensure root .zgroup exists (for empty groupPath)
if strlength(groupPath) == 0
    zgroupFile = fullfile(zarrPath, '.zgroup');
    if ~isfile(zgroupFile)
        writeZgroupFile(zarrPath);
    end
    return;  % Done for root group
end

%% Create each group level
currentPath = zarrPath;
for i = 1:length(parts)
    currentPath = fullfile(currentPath, parts(i));
    
    if ~isfolder(currentPath)
        mkdir(currentPath);
    end
    
    % Always ensure .zgroup exists
    zgroupFile = fullfile(currentPath, '.zgroup');
    if ~isfile(zgroupFile)
        writeZgroupFile(currentPath);
    end
end

end

%% ========================================================================
%% HELPER: Write .zgroup metadata file
%% ========================================================================
function writeZgroupFile(path)
%WRITEZGROUPFILE  Create .zgroup JSON file for Zarr v2
%
% Creates .zgroup file with format version 2 metadata

zgroupPath = fullfile(path, '.zgroup');

% Zarr v2 group metadata
metadata = struct('zarr_format', 2);

% Write JSON
try
    jsonStr = jsonencode(metadata);
    fid = fopen(zgroupPath, 'w');
    if fid == -1
        error('Failed to open .zgroup file for writing');
    end
    fwrite(fid, jsonStr, 'char');
    fclose(fid);
catch ME
    error('bct:file:zarr:createGroup:WriteFailed', ...
        'Failed to create .zgroup file: %s', ME.message);
end

end
