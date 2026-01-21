function writeAttrs(zarrPath, groupPath, attrs)
%BCT.FILE.ZARR.WRITEATTRS  Write attributes to .zattrs JSON
%
%   bct.file.zarr.writeAttrs(zarrPath, groupPath, attrs)
%
% Purpose
%   Writes attributes to a Zarr group or array as .zattrs JSON file.
%   Supports nested structures for hierarchical metadata.
%
% Inputs
%   zarrPath  - string, root Zarr directory (e.g., "bunny.zarr")
%   groupPath - string, group/array path relative to zarrPath (e.g., "manifold")
%   attrs     - struct, attributes to write (must be JSON-serializable)
%
% Examples
%   % Write group attributes
%   attrs = struct('schema', 'bct.manifold@1', 'units', 'm');
%   bct.file.zarr.writeAttrs("mesh.zarr", "manifold", attrs);
%
%   % Write nested attributes
%   attrs.metric.unit = 'm';
%   attrs.metric.rescale.applied = false;
%   bct.file.zarr.writeAttrs("mesh.zarr", "manifold", attrs);
%
% See also: zarrwriteatt, bct.file.zarr.writeArray

arguments
    zarrPath (1,1) string
    groupPath (1,1) string
    attrs (1,1) struct
end

%% Construct full path
fullPath = fullfile(zarrPath, groupPath);

%% Validate path exists
if ~isfolder(fullPath)
    error('bct:file:zarr:writeAttrs:PathNotFound', ...
        'Path "%s" does not exist. Create group or array first.', fullPath);
end

%% Read existing .zattrs if present
attrsFile = fullfile(fullPath, '.zattrs');
if isfile(attrsFile)
    try
        existingAttrs = jsondecode(fileread(attrsFile));
    catch
        existingAttrs = struct();
    end
else
    existingAttrs = struct();
end

%% Merge new attributes
fields = fieldnames(attrs);
for i = 1:length(fields)
    field = fields{i};
    existingAttrs.(field) = attrs.(field);
end

%% Write .zattrs JSON
try
    jsonStr = jsonencode(existingAttrs);
    fid = fopen(attrsFile, 'w');
    if fid == -1
        error('Failed to open .zattrs file');
    end
    fwrite(fid, jsonStr, 'char');
    fclose(fid);
catch ME
    error('bct:file:zarr:writeAttrs:WriteFailed', ...
        'Failed to write .zattrs: %s', ME.message);
end

end
