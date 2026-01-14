function ensureGroup(file, path)
%ENSUREGROUP  Create HDF5 group if it doesn't exist
%
%   bct.file.h5.ensureGroup(file, path)
%
% Purpose
%   Creates an HDF5 group at the specified path, including any parent
%   groups that don't exist. No-op if group already exists.
%
% Inputs
%   file - string, file path
%   path - string, HDF5 group path
%
% Examples
%   bct.file.h5.ensureGroup("mesh.h5", "/manifold/geometry");

arguments
    file (1,1) string
    path (1,1) string
end

% Normalize path
path = bct.file.h5.normalizePath(path);

% Check if already exists
if bct.file.exists(file, path)
    return;
end

% Split path into components
parts = split(path, '/');
parts = parts(strlength(parts) > 0);  % Remove empty strings

% Create each level
currentPath = "";
for i = 1:length(parts)
    currentPath = currentPath + "/" + parts(i);
    
    if ~bct.file.exists(file, currentPath)
        try
            % Create group using h5create with a dummy dataset approach
            % MATLAB doesn't have direct h5creategroup, so we use low-level API
            fid = H5F.open(char(file), 'H5F_ACC_RDWR', 'H5P_DEFAULT');
            plist = H5P.create('H5P_GROUP_CREATE');
            gid = H5G.create(fid, char(currentPath), plist, 'H5P_DEFAULT', 'H5P_DEFAULT');
            H5G.close(gid);
            H5P.close(plist);
            H5F.close(fid);
        catch ME
            error('bct:file:h5:ensureGroup:CreateFailed', ...
                'Failed to create group "%s": %s', currentPath, ME.message);
        end
    end
end

end
