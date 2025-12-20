function defs = colormaps()
%BCT.REGISTRY.COLORMAPS  Registry of available colormaps
%
%   defs = bct.registry.colormaps()
%
% Purpose
%   Authoritative metadata list of supported colormaps.
%   This is the single source of truth for what colormaps exist.
%
% Outputs
%   defs - struct array (1×K) with fields:
%          Id        (string): canonical colormap ID (case-sensitive)
%          Provider  (string): "matlab" or "bct"
%          Kind      (string): "sequential"|"diverging"|"cyclic"|"categorical"
%          DefaultN  (integer): recommended number of colors (e.g., 256)
%          Tags      (string array): optional classification tags
%          Notes     (string): optional description
%
% Contract
%   - Registry contains NO UI state
%   - Registry ordering is default UI ordering (for dropdowns)
%   - IDs must be unique
%   - Provider determines how runtime resolves the colormap:
%     * "matlab" → calls MATLAB built-in: feval(id, n)
%     * "bct" → calls bct.ui.color.maps.<id>(n)
%
% See also: bct.runtime.colormap, bct.ui.color.list

    % Build registry as cell array of entries, then convert to struct array
    entries = {
        % MATLAB built-in colormaps
        makeEntry("parula",   "matlab", "sequential", 256, ["default"], "MATLAB default sequential colormap")
        makeEntry("turbo",    "matlab", "sequential", 256, ["perceptual"], "Smooth rainbow variant")
        makeEntry("jet",      "matlab", "sequential", 256, ["classic"], "Classic rainbow (legacy)")
        makeEntry("hot",      "matlab", "sequential", 256, ["thermal"], "Black-red-yellow-white")
        makeEntry("cool",     "matlab", "sequential", 256, string.empty(0,1), "Cyan-magenta")
        makeEntry("spring",   "matlab", "sequential", 256, string.empty(0,1), "Magenta-yellow")
        makeEntry("summer",   "matlab", "sequential", 256, string.empty(0,1), "Green-yellow")
        makeEntry("autumn",   "matlab", "sequential", 256, string.empty(0,1), "Red-yellow")
        makeEntry("winter",   "matlab", "sequential", 256, string.empty(0,1), "Blue-green")
        makeEntry("gray",     "matlab", "sequential", 256, ["monochrome"], "Linear grayscale")
        makeEntry("bone",     "matlab", "sequential", 256, ["monochrome"], "Gray with blue tint")
        makeEntry("copper",   "matlab", "sequential", 256, string.empty(0,1), "Linear copper-tone")
        makeEntry("pink",     "matlab", "sequential", 256, string.empty(0,1), "Pastel shades")
        makeEntry("lines",    "matlab", "categorical", 7, ["discrete"], "Line plot colors")
        makeEntry("colorcube","matlab", "categorical", 64, ["discrete"], "Maximal color separation")
        makeEntry("prism",    "matlab", "categorical", 12, ["discrete"], "Prism colors")
        makeEntry("flag",     "matlab", "categorical", 4, ["discrete"], "Red-white-blue-black")
        makeEntry("hsv",      "matlab", "cyclic", 256, string.empty(0,1), "Hue-based cyclic")
        
        % BCT custom colormaps
        makeEntry("redblue",  "bct", "diverging", 256, ["signed"; "diverging"], "Red-white-blue diverging colormap")
    };
    
    % Convert cell array to struct array
    defs = [entries{:}];
end

function entry = makeEntry(id, provider, kind, defaultN, tags, notes)
    % Helper to construct registry entry
    arguments
        id (1,1) string
        provider (1,1) string {mustBeMember(provider, ["matlab", "bct"])}
        kind (1,1) string {mustBeMember(kind, ["sequential", "diverging", "cyclic", "categorical"])}
        defaultN (1,1) double {mustBePositive, mustBeInteger}
        tags string = string.empty(0,1)
        notes (1,1) string = ""
    end
    
    entry = struct(...
        "Id", id, ...
        "Provider", provider, ...
        "Kind", kind, ...
        "DefaultN", defaultN, ...
        "Tags", tags, ...
        "Notes", notes);
end
