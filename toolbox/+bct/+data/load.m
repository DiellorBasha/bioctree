function mesh = load(id, options)
%BCT.DATA.LOAD Load bundled mesh asset
%
% Syntax:
%   mesh = bct.data.load()                    % Load default
%   mesh = bct.data.load(id)                  % Load by ID
%   mesh = bct.data.load(Name=Value)          % Load by attributes
%
% Inputs:
%   id - Asset ID string (e.g., "fsaverage6_hemi-lh_surf-pial")
%
% Optional Parameters (for attribute-based selection):
%   Dataset  - Dataset name (e.g., "fsaverage6")
%   Hemi     - Hemisphere: "lh" | "rh"
%   Surface  - Surface type: "pial" | "white" | "inflated"
%
% Outputs:
%   mesh - Struct with fields:
%          .Vertices - [N×3] vertex coordinates
%          .Faces    - [M×3] face connectivity
%          .Meta     - Metadata struct with dataset info
%          .V        - Alias for Vertices (backward compatibility)
%          .F        - Alias for Faces (backward compatibility)
%
% Examples:
%   % Load default (fsaverage6 left hemisphere pial)
%   mesh = bct.data.load();
%   M = bct.Manifold(mesh);
%
%   % Load by ID
%   mesh = bct.data.load("fsaverage6_hemi-rh_surf-pial");
%
%   % Load by attributes
%   mesh = bct.data.load(Dataset="fsaverage6", Hemi="lh", Surface="pial");
%
% See also: bct.data.index, bct.data.list, bct.Manifold

arguments
    id (1,1) string = ""
    options.Dataset (1,1) string = ""
    options.Hemi (1,1) string = ""
    options.Surface (1,1) string = ""
end

% Get catalog
catalog = bct.data.index();

% Determine which asset to load
if id == "" && options.Dataset == "" && options.Hemi == "" && options.Surface == ""
    % Load default
    idx = find([catalog.Default], 1);
    if isempty(idx)
        error('bct:data:NoDefault', 'No default asset found in catalog');
    end
    entry = catalog(idx);
    
elseif id ~= ""
    % Load by ID - use == for string comparison
    ids = [catalog.Id];  % Convert to string array
    idx = find(ids == id, 1);
    if isempty(idx)
        error('bct:data:UnknownID', 'Asset ID "%s" not found in catalog', id);
    end
    entry = catalog(idx);
    
else
    % Load by attributes - use == for string arrays
    mask = true(size(catalog));
    
    if options.Dataset ~= ""
        datasets = [catalog.Dataset];
        mask = mask & (datasets == options.Dataset);
    end
    
    if options.Hemi ~= ""
        hemis = [catalog.Hemi];
        mask = mask & (hemis == options.Hemi);
    end
    
    if options.Surface ~= ""
        surfaces = [catalog.Surface];
        mask = mask & (surfaces == options.Surface);
    end
    
    idx = find(mask, 1);
    if isempty(idx)
        error('bct:data:NoMatch', ...
            'No asset matches: Dataset=%s, Hemi=%s, Surface=%s', ...
            options.Dataset, options.Hemi, options.Surface);
    end
    
    entry = catalog(idx);
end

% Build full path
data_dir = fileparts(mfilename('fullpath'));
assets_dir = fullfile(data_dir, 'assets');
full_path = fullfile(assets_dir, entry.Path);

% Verify file exists
if ~exist(full_path, 'file')
    error('bct:data:FileNotFound', ...
        'Asset file not found: %s', full_path);
end

% Load data
try
    data = load(full_path);
catch ME
    error('bct:data:LoadFailed', ...
        'Failed to load asset "%s": %s', entry.Id, ME.message);
end

% Extract V and F (support both naming conventions)
if isfield(data, 'Vertices')
    V = data.Vertices;
elseif isfield(data, 'V')
    V = data.V;
else
    error('bct:data:MissingVertices', ...
        'Asset file must contain Vertices or V field');
end

if isfield(data, 'Faces')
    F = data.Faces;
elseif isfield(data, 'F')
    F = data.F;
else
    error('bct:data:MissingFaces', ...
        'Asset file must contain Faces or F field');
end

% Build metadata (merge file metadata with catalog entry)
meta = struct();
meta.Id = entry.Id;
meta.Dataset = entry.Dataset;
meta.Hemi = entry.Hemi;
meta.Surface = entry.Surface;
meta.Tags = entry.Tags;
meta.NumVertices = size(V, 1);
meta.NumFaces = size(F, 1);

% Merge any metadata from file
if isfield(data, 'Meta')
    file_meta = data.Meta;
    meta_fields = fieldnames(file_meta);
    for i = 1:numel(meta_fields)
        field = meta_fields{i};
        if ~isfield(meta, field)
            meta.(field) = file_meta.(field);
        end
    end
elseif isfield(data, 'meta')
    file_meta = data.meta;
    meta_fields = fieldnames(file_meta);
    for i = 1:numel(meta_fields)
        field = meta_fields{i};
        if ~isfield(meta, field)
            meta.(field) = file_meta.(field);
        end
    end
end

% Construct output struct
mesh = struct();
mesh.Vertices = V;
mesh.Faces = F;
mesh.Meta = meta;

% Add aliases for backward compatibility
mesh.V = V;
mesh.F = F;

end
