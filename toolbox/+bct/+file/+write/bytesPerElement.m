function b = bytesPerElement(dtype)
%BYTESPERELEMENT Get number of bytes per element for a data type
%
% Syntax:
%   b = bct.file.write.bytesPerElement(dtype)
%
% Inputs:
%   dtype - Data type string: 'float32', 'float64', 'double',
%           'uint32', 'uint16', 'uint8', 'int32', 'int16', 'int8'
%
% Outputs:
%   b - Number of bytes per element
%
% Examples:
%   b = bct.file.write.bytesPerElement('float32')  % Returns 4
%   b = bct.file.write.bytesPerElement('double')   % Returns 8

dtype = string(dtype);

switch dtype
    case {"float32", "single"}
        b = 4;
    case {"float64", "double"}
        b = 8;
    case {"uint32", "int32"}
        b = 4;
    case {"uint16", "int16"}
        b = 2;
    case {"uint8", "int8"}
        b = 1;
    case "uint64"
        b = 8;
    case "int64"
        b = 8;
    otherwise
        error('bct:file:write:UnsupportedDtype', ...
            'Unsupported dtype: %s', dtype);
end

end
