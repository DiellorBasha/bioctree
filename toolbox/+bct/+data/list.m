function ids = list(options)
%BCT.DATA.LIST List available mesh assets
%
% Syntax:
%   ids = bct.data.list()                    % List all
%   ids = bct.data.list(Name=Value)          % Filter by attributes
%
% Optional Parameters:
%   Dataset  - Filter by dataset (e.g., "fsaverage6")
%   Hemi     - Filter by hemisphere: "lh" | "rh"
%   Surface  - Filter by surface type: "pial" | "white" | "inflated"
%   Tags     - Filter by tags (string array)
%
% Outputs:
%   ids - String array of asset IDs
%
% Examples:
%   % List all available assets
%   all_ids = bct.data.list();
%
%   % List only fsaverage6 assets
%   fs6_ids = bct.data.list(Dataset="fsaverage6");
%
%   % List only left hemisphere assets
%   lh_ids = bct.data.list(Hemi="lh");
%
%   % List pial surfaces
%   pial_ids = bct.data.list(Surface="pial");
%
%   % List by tag
%   cortical_ids = bct.data.list(Tags="cortical");
%
% See also: bct.data.load, bct.data.index, bct.data.info

arguments
    options.Dataset (1,1) string = ""
    options.Hemi (1,1) string = ""
    options.Surface (1,1) string = ""
    options.Tags (1,:) string = string.empty
end

% Get catalog
catalog = bct.data.index();

% Apply filters
mask = true(size(catalog));

if options.Dataset ~= ""
    mask = mask & strcmp({catalog.Dataset}, options.Dataset);
end

if options.Hemi ~= ""
    mask = mask & strcmp({catalog.Hemi}, options.Hemi);
end

if options.Surface ~= ""
    mask = mask & strcmp({catalog.Surface}, options.Surface);
end

if ~isempty(options.Tags)
    tag_mask = false(size(catalog));
    for i = 1:numel(catalog)
        if any(ismember(options.Tags, catalog(i).Tags))
            tag_mask(i) = true;
        end
    end
    mask = mask & tag_mask;
end

% Extract IDs
filtered = catalog(mask);
ids = string({filtered.Id});

end
