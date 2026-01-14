function value = readAttribute(file, path, attrName)
%READATTRIBUTE  Read HDF5 attribute using h5readatt
%
%   value = bct.file.h5.readAttribute(file, path, attrName)
%
% Purpose
%   Low-level wrapper around h5readatt for reading attributes.
%
% Inputs
%   file     - string, file path
%   path     - string, HDF5 path (group or dataset)
%   attrName - string, attribute name
%
% Output
%   value - attribute value

arguments
    file (1,1) string
    path (1,1) string
    attrName (1,1) string
end

% Normalize path
path = bct.file.h5.normalizePath(path);

% Read using h5readatt
try
    value = h5readatt(file, char(path), char(attrName));
    
    % Convert to string if it's a char array
    if ischar(value)
        value = string(value);
    end
catch ME
    error('bct:file:h5:readAttribute:ReadFailed', ...
        'Failed to read attribute "%s" from "%s": %s', ...
        attrName, path, ME.message);
end

end
