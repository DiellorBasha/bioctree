function s = readJson(filePath)
%READJSON Read and parse JSON file
%
% Inputs:
%   filePath - Path to JSON file
%
% Returns:
%   s - Parsed struct

if ~exist(filePath, 'file')
    error('bct:config:FileNotFound', 'JSON file not found: %s', filePath);
end

try
    txt = fileread(filePath);
    s = jsondecode(txt);
catch ME
    error('bct:config:InvalidJson', 'Failed to parse JSON file %s: %s', ...
        filePath, ME.message);
end

end
