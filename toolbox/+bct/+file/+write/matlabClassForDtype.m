function cls = matlabClassForDtype(dtype)
%MATLABCLASSFORDTYPE Convert dtype string to MATLAB class name
%
% Syntax:
%   cls = bct.file.write.matlabClassForDtype(dtype)
%
% Inputs:
%   dtype - Data type string: 'float32', 'float64', 'double',
%           'uint32', 'uint16', 'uint8', 'int32', 'int16', 'int8'
%
% Outputs:
%   cls - MATLAB class name string for fwrite
%
% Examples:
%   cls = bct.file.write.matlabClassForDtype('float32')  % Returns 'single'
%   cls = bct.file.write.matlabClassForDtype('double')   % Returns 'double'

dtype = string(dtype);

switch dtype
    case {"float32", "single"}
        cls = 'single';
    case {"float64", "double"}
        cls = 'double';
    case "uint32"
        cls = 'uint32';
    case "uint16"
        cls = 'uint16';
    case "uint8"
        cls = 'uint8';
    case "int32"
        cls = 'int32';
    case "int16"
        cls = 'int16';
    case "int8"
        cls = 'int8';
    case "uint64"
        cls = 'uint64';
    case "int64"
        cls = 'int64';
    otherwise
        error('bct:file:write:UnsupportedDtype', ...
            'Unsupported dtype: %s', dtype);
end

end
