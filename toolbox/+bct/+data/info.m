function info = info(id)
%BCT.DATA.INFO Get detailed information about a mesh asset
%
% Syntax:
%   info = bct.data.info(id)
%
% Inputs:
%   id - Asset ID string (e.g., "fsaverage6_hemi-lh_surf-pial")
%
% Outputs:
%   info - Struct with fields:
%          .Id          - Asset ID
%          .Dataset     - Dataset name
%          .Hemi        - Hemisphere
%          .Surface     - Surface type
%          .Path        - File path relative to assets/
%          .FullPath    - Absolute file path
%          .Default     - Whether this is the default asset
%          .Tags        - Descriptive tags
%          .Exists      - Whether file exists on disk
%          .NumVertices - Number of vertices (if file exists)
%          .NumFaces    - Number of faces (if file exists)
%          .FileMeta    - Metadata from file (if exists)
%
% Examples:
%   % Get info about default asset
%   info = bct.data.info("fsaverage6_hemi-lh_surf-pial");
%   fprintf('Vertices: %d, Faces: %d\n', info.NumVertices, info.NumFaces);
%
%   % Check if asset exists
%   if info.Exists
%       mesh = bct.data.load(info.Id);
%   end
%
% See also: bct.data.load, bct.data.list, bct.data.index

arguments
    id (1,1) string
end

% Get catalog
catalog = bct.data.index();

% Find entry
idx = find(strcmp({catalog.Id}, id), 1);
if isempty(idx)
    error('bct:data:UnknownID', ...
        'Asset ID "%s" not found in catalog', id);
end

entry = catalog(idx);

% Build base info from catalog
info = struct();
info.Id = entry.Id;
info.Dataset = entry.Dataset;
info.Hemi = entry.Hemi;
info.Surface = entry.Surface;
info.Path = entry.Path;
info.Default = entry.Default;
info.Tags = entry.Tags;

% Build full path
data_dir = fileparts(mfilename('fullpath'));
assets_dir = fullfile(data_dir, 'assets');
full_path = fullfile(assets_dir, entry.Path);
info.FullPath = full_path;

% Check if file exists
info.Exists = exist(full_path, 'file') == 2;

% If file exists, load metadata
if info.Exists
    try
        data = load(full_path);
        
        % Extract dimensions
        if isfield(data, 'V')
            info.NumVertices = size(data.V, 1);
        elseif isfield(data, 'Vertices')
            info.NumVertices = size(data.Vertices, 1);
        else
            info.NumVertices = NaN;
        end
        
        if isfield(data, 'F')
            info.NumFaces = size(data.F, 1);
        elseif isfield(data, 'Faces')
            info.NumFaces = size(data.Faces, 1);
        else
            info.NumFaces = NaN;
        end
        
        % Extract file metadata if present
        if isfield(data, 'Meta')
            info.FileMeta = data.Meta;
        elseif isfield(data, 'meta')
            info.FileMeta = data.meta;
        else
            info.FileMeta = struct();
        end
        
    catch ME
        warning('bct:data:LoadMetadataFailed', ...
            'Failed to load metadata from "%s": %s', id, ME.message);
        info.NumVertices = NaN;
        info.NumFaces = NaN;
        info.FileMeta = struct();
    end
else
    info.NumVertices = NaN;
    info.NumFaces = NaN;
    info.FileMeta = struct();
end

end
