function write(file, path, value, options)
%BCT.FILE.WRITE  Write a dataset to HDF5 file
%
%   bct.file.write(file, path, value)
%   bct.file.write(file, path, value, Name=Value)
%
% Purpose
%   Writes a dataset to the specified path in the HDF5 file.
%   Creates parent groups automatically if needed.
%
% Inputs
%   file  - string or char, file path
%   path  - string or char, HDF5 dataset path
%   value - numeric array, string, or other HDF5-compatible data
%
% Name-Value Arguments
%   Overwrite - logical (default true), overwrite if exists
%   Attrs     - struct (optional), attributes to write to dataset
%
% Examples
%   % Write vertices
%   V = rand(1000, 3);
%   bct.file.write("mesh.h5", "/manifold/vertices", V);
%
%   % Write with attributes
%   bct.file.write("mesh.h5", "/manifold/geometry/faceAreas/value", areas, ...
%       "Attrs", struct("unit", "m^2", "dimLexp", 2));
%
%   % Prevent overwrite
%   bct.file.write("mesh.h5", "/manifold/faces", F, "Overwrite", false);
%
% See also: bct.file.read, bct.file.writeAttrs, bct.file.h5.writeDataset

arguments
    file (1,1) string
    path (1,1) string
    value
    options.Overwrite (1,1) logical = true
    options.Attrs (1,1) struct = struct()
end

%% Validate inputs
if ~isfile(file)
    error('bct:file:write:FileNotFound', ...
        'File "%s" does not exist. Use bct.file.create first.', file);
end

%% Check if path exists
if bct.file.exists(file, path)
    if ~options.Overwrite
        error('bct:file:write:PathExists', ...
            'Path "%s" already exists and Overwrite=false.', path);
    end
    % Delete existing dataset if overwriting
    % Note: HDF5 doesn't support simple delete, so we'll handle via writeDataset
end

%% Ensure parent group exists
parentPath = extractBefore(path, max(strfind(path, '/')));
if strlength(parentPath) > 0 && ~bct.file.exists(file, parentPath)
    bct.file.h5.ensureGroup(file, parentPath);
end

%% Delegate to h5 layer
bct.file.h5.writeDataset(file, path, value, "Overwrite", options.Overwrite);

%% Write attributes if provided
if ~isempty(fieldnames(options.Attrs))
    bct.file.writeAttrs(file, path, options.Attrs);
end

end
