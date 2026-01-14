function writeAttrs(file, path, attrs)
%BCT.FILE.WRITEATTRS  Write attributes to a path in HDF5 file
%
%   bct.file.writeAttrs(file, path, attrs)
%
% Purpose
%   Writes all fields of a struct as attributes to the specified path
%   (group or dataset) in the HDF5 file.
%
% Inputs
%   file  - string or char, file path
%   path  - string or char, HDF5 path (must exist)
%   attrs - struct with attribute names as fields
%
% Examples
%   % Write attributes to /manifold
%   attrs = struct("units_length", "m", "index_base_faces", int32(1));
%   bct.file.writeAttrs("mesh.h5", "/manifold", attrs);
%
%   % Write quantity metadata
%   attrs = struct("unit", "m^2", "dimLexp", 2);
%   bct.file.writeAttrs("mesh.h5", "/manifold/geometry/faceAreas", attrs);
%
% See also: bct.file.readAttrs, bct.file.write

arguments
    file (1,1) string
    path (1,1) string
    attrs (1,1) struct
end

%% Validate inputs
if ~isfile(file)
    error('bct:file:writeAttrs:FileNotFound', ...
        'File "%s" does not exist.', file);
end

if ~bct.file.exists(file, path)
    error('bct:file:writeAttrs:PathNotFound', ...
        'Path "%s" does not exist. Create it first.', path);
end

%% Write each field as an attribute
fieldNames = fieldnames(attrs);

for i = 1:length(fieldNames)
    attrName = fieldNames{i};
    attrValue = attrs.(attrName);
    
    try
        bct.file.h5.writeAttribute(file, path, attrName, attrValue);
    catch ME
        error('bct:file:writeAttrs:AttributeWriteFailed', ...
            'Failed to write attribute "%s" to "%s": %s', ...
            attrName, path, ME.message);
    end
end

end
