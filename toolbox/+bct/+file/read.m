function value = read(file, path, options)
%BCT.FILE.READ  Read a dataset from HDF5 file
%
%   value = bct.file.read(file, path)
%
% Purpose
%   Reads a dataset at the specified path in the HDF5 file.
%
% Inputs
%   file - string or char, file path
%   path - string or char, HDF5 dataset path
%
% Name-Value Arguments
%   As - "native" (default) | "double"
%        Data type casting for numeric data
%
% Output
%   value - dataset contents (numeric array, string, etc.)
%
% Examples
%   % Read vertices
%   V = bct.file.read("mesh.h5", "/manifold/vertices");
%
%   % Read and cast to double
%   F = bct.file.read("mesh.h5", "/manifold/faces", "As", "double");
%
% See also: bct.file.write, bct.file.exists, bct.file.h5.readDataset

arguments
    file (1,1) string
    path (1,1) string
    options.As (1,1) string {mustBeMember(options.As, ["native", "double"])} = "native"
end

%% Validate inputs
if ~isfile(file)
    error('bct:file:read:FileNotFound', ...
        'File "%s" does not exist.', file);
end

if ~bct.file.exists(file, path)
    error('bct:file:read:PathNotFound', ...
        'Path "%s" does not exist in file.', path);
end

%% Delegate to h5 layer
value = bct.file.h5.readDataset(file, path);

%% Apply casting if requested
if strcmp(options.As, "double") && isnumeric(value)
    value = double(value);
end

end
