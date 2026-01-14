function tf = exists(file, path)
%BCT.FILE.EXISTS  Check if a path exists in HDF5 file
%
%   tf = bct.file.exists(file, path)
%
% Purpose
%   Check whether a dataset or group exists at the specified path in the
%   HDF5 file.
%
% Inputs
%   file - string or char, file path
%   path - string or char, HDF5 path (e.g., "/manifold/vertices")
%
% Output
%   tf - logical, true if path exists
%
% Examples
%   if bct.file.exists("mesh.h5", "/manifold/vertices")
%       V = bct.file.read("mesh.h5", "/manifold/vertices");
%   end
%
% See also: bct.file.list, bct.file.read, bct.file.write

arguments
    file (1,1) string
    path (1,1) string
end

%% Check file exists first
if ~isfile(file)
    tf = false;
    return;
end

%% Normalize path
path = bct.file.h5.normalizePath(path);

%% Check if path exists using h5info
try
    h5info(file, path);
    tf = true;
catch
    tf = false;
end

end
