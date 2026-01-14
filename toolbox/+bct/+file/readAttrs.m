function attrs = readAttrs(file, path)
%BCT.FILE.READATTRS  Read all attributes from a path in HDF5 file
%
%   attrs = bct.file.readAttrs(file, path)
%
% Purpose
%   Reads all attributes attached to a dataset or group and returns them
%   as a MATLAB struct.
%
% Inputs
%   file - string or char, file path
%   path - string or char, HDF5 path (group or dataset)
%
% Output
%   attrs - struct with attribute names as fields
%
% Examples
%   % Read root attributes
%   rootAttrs = bct.file.readAttrs("mesh.h5", "/");
%   schema = rootAttrs.schema;
%
%   % Read /manifold attributes
%   manifoldAttrs = bct.file.readAttrs("mesh.h5", "/manifold");
%   units = manifoldAttrs.units_length;
%
% See also: bct.file.writeAttrs, bct.file.read

arguments
    file (1,1) string
    path (1,1) string
end

%% Validate inputs
if ~isfile(file)
    error('bct:file:readAttrs:FileNotFound', ...
        'File "%s" does not exist.', file);
end

if ~bct.file.exists(file, path)
    error('bct:file:readAttrs:PathNotFound', ...
        'Path "%s" does not exist in file.', path);
end

%% Normalize path
path = bct.file.h5.normalizePath(path);

%% Get info to enumerate attributes
try
    info = h5info(file, path);
catch ME
    error('bct:file:readAttrs:ReadFailed', ...
        'Failed to read info for "%s": %s', path, ME.message);
end

%% Read each attribute
attrs = struct();

if isfield(info, 'Attributes') && ~isempty(info.Attributes)
    for i = 1:length(info.Attributes)
        attrName = info.Attributes(i).Name;
        try
            attrValue = bct.file.h5.readAttribute(file, path, attrName);
            % Convert to valid MATLAB field name if needed
            validName = matlab.lang.makeValidName(attrName);
            attrs.(validName) = attrValue;
        catch ME
            warning('bct:file:readAttrs:AttributeReadFailed', ...
                'Failed to read attribute "%s" at "%s": %s', ...
                attrName, path, ME.message);
        end
    end
end

end
