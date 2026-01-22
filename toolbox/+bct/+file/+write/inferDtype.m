function dtype = inferDtype(data)
%INFERDTYPE Infer data type string from MATLAB array class
%
% Syntax:
%   dtype = bct.file.write.inferDtype(data)
%
% Inputs:
%   data - MATLAB numeric array
%
% Outputs:
%   dtype - Data type string compatible with JSON schema
%
% Examples:
%   dtype = bct.file.write.inferDtype(single([1 2 3]))  % Returns 'float32'
%   dtype = bct.file.write.inferDtype([1 2 3])          % Returns 'float64'

cls = class(data);

switch cls
    case 'single'
        dtype = 'float32';
    case 'double'
        dtype = 'float64';
    case 'uint32'
        dtype = 'uint32';
    case 'uint16'
        dtype = 'uint16';
    case 'uint8'
        dtype = 'uint8';
    case 'int32'
        dtype = 'int32';
    case 'int16'
        dtype = 'int16';
    case 'int8'
        dtype = 'int8';
    case 'uint64'
        dtype = 'uint64';
    case 'int64'
        dtype = 'int64';
    case 'logical'
        dtype = 'uint8';  % Store logical as uint8
    otherwise
        error('bct:file:write:UnsupportedClass', ...
            'Unsupported MATLAB class: %s', cls);
end

end
