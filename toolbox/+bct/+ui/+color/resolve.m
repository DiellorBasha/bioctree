function cmap = resolve(colormapId, n)
%BCT.UI.COLOR.RESOLVE  Resolve colormap ID to N×3 array (façade)
%
%   cmap = bct.ui.color.resolve(colormapId)
%   cmap = bct.ui.color.resolve(colormapId, n)
%
% Purpose
%   User-facing wrapper that delegates to bct.runtime.colormaps.resolve().
%   Resolves a colormap ID to an [n×3] colormap matrix.
%
% Inputs
%   colormapId - string scalar, colormap identifier
%   n          - (optional) positive integer, number of colors
%                If omitted, uses registry DefaultN
%
% Output
%   cmap       - [n×3] double in [0,1]
%
% Usage
%   % Use default size
%   cmap = bct.ui.color.resolve("parula");
%
%   % Specify size
%   cmap = bct.ui.color.resolve("redblue", 128);
%
% Note
%   This is a façade function. For new code, prefer:
%     cmap = bct.runtime.colormaps.resolve(colormapId, n);
%
% See also: bct.runtime.colormaps.resolve, bct.ui.color.rgb

    arguments
        colormapId (1,1) string
        n {mustBePositiveInteger} = []
    end

    % Delegate to authoritative runtime
    if isempty(n)
        cmap = bct.runtime.colormaps.resolve(colormapId);
    else
        cmap = bct.runtime.colormaps.resolve(colormapId, n);
    end
end

function mustBePositiveInteger(x)
    if ~isempty(x)
        validateattributes(x, {'numeric'}, {'scalar', 'positive', 'integer'});
    end
end
