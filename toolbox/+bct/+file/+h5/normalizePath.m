function path = normalizePath(path)
%NORMALIZEPATH  Normalize HDF5 path to canonical form
%
%   path = bct.file.h5.normalizePath(path)
%
% Purpose
%   Ensures HDF5 paths start with '/' and removes trailing slashes.
%
% Input
%   path - string or char, HDF5 path
%
% Output
%   path - string, normalized path
%
% Examples
%   bct.file.h5.normalizePath("manifold")       % -> "/manifold"
%   bct.file.h5.normalizePath("/manifold/")     % -> "/manifold"
%   bct.file.h5.normalizePath("/")              % -> "/"

arguments
    path (1,1) string
end

% Convert to string
path = string(path);

% Ensure starts with /
if ~startsWith(path, "/")
    path = "/" + path;
end

% Remove trailing / unless it's root
if path ~= "/" && endsWith(path, "/")
    path = extractBefore(path, strlength(path));
end

end
