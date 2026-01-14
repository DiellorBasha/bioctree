function names = list(file, path, options)
%BCT.FILE.LIST  List children names at a path in HDF5 file
%
%   names = bct.file.list(file, path)
%
% Purpose
%   Returns names of child groups and datasets at the specified path.
%
% Inputs
%   file - string or char, file path
%   path - string or char, HDF5 path (default "/")
%
% Name-Value Arguments
%   Type - "all" (default) | "groups" | "datasets"
%          Filter by type
%
% Output
%   names - string array of child names (not full paths, just names)
%
% Examples
%   % List all children under /manifold
%   children = bct.file.list("mesh.h5", "/manifold");
%
%   % List only groups
%   groups = bct.file.list("mesh.h5", "/manifold", "Type", "groups");
%
% See also: bct.file.exists, bct.file.read

arguments
    file (1,1) string
    path (1,1) string = "/"
    options.Type (1,1) string {mustBeMember(options.Type, ["all", "groups", "datasets"])} = "all"
end

%% Validate inputs
if ~isfile(file)
    error('bct:file:list:FileNotFound', ...
        'File "%s" does not exist.', file);
end

if ~bct.file.exists(file, path)
    error('bct:file:list:PathNotFound', ...
        'Path "%s" does not exist in file.', path);
end

%% Normalize path
path = bct.file.h5.normalizePath(path);

%% Get info
try
    info = h5info(file, path);
catch ME
    error('bct:file:list:ReadFailed', ...
        'Failed to read path "%s": %s', path, ME.message);
end

%% Extract names based on type
names = string([]);

if strcmp(options.Type, "all") || strcmp(options.Type, "groups")
    if isfield(info, 'Groups') && ~isempty(info.Groups)
        groupNames = arrayfun(@(g) string(extractAfter(g.Name, strlength(path) + 1)), ...
            info.Groups);
        names = [names; groupNames(:)];
    end
end

if strcmp(options.Type, "all") || strcmp(options.Type, "datasets")
    if isfield(info, 'Datasets') && ~isempty(info.Datasets)
        datasetNames = string({info.Datasets.Name})';
        names = [names; datasetNames];
    end
end

% Remove empty strings and duplicates
names = unique(names(strlength(names) > 0));

end
