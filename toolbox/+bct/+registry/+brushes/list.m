function ids = list(varargin)
%BCT.REGISTRY.BRUSHES.LIST  List available brushes
%
%   ids = bct.registry.brushes.list()
%   ids = bct.registry.brushes.list('Category', category)
%   ids = bct.registry.brushes.list('Tag', tag)
%
% Purpose:
%   Convenience function to list brush IDs with optional filtering
%
% Optional Parameters:
%   'Category' - Filter by category: "patch"|"trajectory"|"time"|"dynamic"
%   'Tag'      - Filter by tag (e.g., "spectral", "geometric")
%   'Requires' - Filter by requirement (e.g., "FEM", "Graph")
%
% Output:
%   ids - string array of brush IDs
%
% Examples:
%   % List all brushes
%   ids = bct.registry.brushes.list()
%
%   % List patch brushes
%   ids = bct.registry.brushes.list('Category', 'patch')
%
%   % List spectral brushes
%   ids = bct.registry.brushes.list('Tag', 'spectral')
%
% See also: bct.registry.brushes.defs

    % Parse inputs
    p = inputParser;
    addParameter(p, 'Category', "", @(x) isstring(x) || ischar(x));
    addParameter(p, 'Tag', "", @(x) isstring(x) || ischar(x));
    addParameter(p, 'Requires', "", @(x) isstring(x) || ischar(x));
    parse(p, varargin{:});
    
    filterCategory = string(p.Results.Category);
    filterTag = string(p.Results.Tag);
    filterRequires = string(p.Results.Requires);
    
    % Get all brush definitions
    defs = bct.registry.brushes.defs();
    
    % Apply filters
    mask = true(1, length(defs));
    
    if filterCategory ~= ""
        for i = 1:length(defs)
            if defs(i).Category ~= filterCategory
                mask(i) = false;
            end
        end
    end
    
    if filterTag ~= ""
        for i = 1:length(defs)
            if ~isfield(defs(i), 'Tags') || ~any(contains(defs(i).Tags, filterTag))
                mask(i) = false;
            end
        end
    end
    
    if filterRequires ~= ""
        for i = 1:length(defs)
            if ~isfield(defs(i), 'Requires') || ~any(contains(defs(i).Requires, filterRequires))
                mask(i) = false;
            end
        end
    end
    
    % Extract IDs
    filtered = defs(mask);
    if isempty(filtered)
        ids = string([]);
    else
        ids = string({filtered.Id});
    end
end
