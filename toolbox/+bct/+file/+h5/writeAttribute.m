function writeAttribute(file, path, attrName, value)
%WRITEATTRIBUTE  Write HDF5 attribute using h5writeatt
%
%   bct.file.h5.writeAttribute(file, path, attrName, value)
%
% Purpose
%   Low-level wrapper for writing attributes to HDF5.
%
% Inputs
%   file     - string, file path
%   path     - string, HDF5 path (must exist)
%   attrName - string, attribute name
%   value    - attribute value (string, numeric, etc.)

arguments
    file (1,1) string
    path (1,1) string
    attrName (1,1) string
    value
end

% Normalize path
path = bct.file.h5.normalizePath(path);

% Convert string to char for h5writeatt
if isstring(value)
    value = char(value);
end

% Write using h5writeatt
try
    h5writeatt(file, char(path), char(attrName), value);
catch ME
    error('bct:file:h5:writeAttribute:WriteFailed', ...
        'Failed to write attribute "%s" to "%s": %s', ...
        attrName, path, ME.message);
end

end
