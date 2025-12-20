function C = resolve(id, n)
%BCT.RUNTIME.COLORMAPS.RESOLVE  Resolve colormap ID to RGB array
%
%   C = bct.runtime.colormaps.resolve(id)
%   C = bct.runtime.colormaps.resolve(id, n)
%
% Purpose
%   Resolves a colormap ID into an [n×3] RGB colormap array.
%   Uses runtime dictionary for dispatch.
%
% Inputs
%   id - string scalar, colormap identifier
%   n  - (optional) positive integer, number of colors
%        If omitted, uses registry DefaultN for the colormap
%
% Output
%   C - [n×3] double array in [0,1] range, RGB colormap
%
% Usage
%   % Use default size
%   C = bct.runtime.colormaps.resolve("parula");
%
%   % Specify size
%   C = bct.runtime.colormaps.resolve("redblue", 128);
%
% See also: bct.runtime.colormaps.dictionary, bct.ui.color.resolve

    arguments
        id (1,1) string
        n {mustBePositiveInteger} = []
    end
    
    % Get registry entry to find DefaultN if needed
    defs = bct.registry.colormaps.defs();
    idx = find([defs.Id] == id, 1);
    
    if isempty(idx)
        error('bct:runtime:colormaps:UnknownId', ...
            'Unknown colormap ID: "%s". Available: %s', ...
            id, strjoin(string({defs.Id}), ', '));
    end
    
    entry = defs(idx);
    
    % Use DefaultN if n not provided
    if isempty(n)
        n = entry.DefaultN;
    end
    
    % Get generator from dictionary
    D = bct.runtime.colormaps.dictionary();
    
    if ~isKey(D, id)
        error('bct:runtime:colormaps:IdNotInDictionary', ...
            'Colormap "%s" is in registry but missing from runtime dictionary', id);
    end
    
    generator = D(id);
    
    % Generate colormap
    try
        C = generator(n);
    catch ME
        error('bct:runtime:colormaps:GeneratorFailed', ...
            'Failed to generate colormap "%s" with n=%d: %s', ...
            id, n, ME.message);
    end
    
    % Validate output
    if ~isnumeric(C) || size(C, 2) ~= 3 || size(C, 1) ~= n
        error('bct:runtime:colormaps:InvalidOutput', ...
            'Colormap generator "%s" returned invalid output (expected %d×3, got %s)', ...
            id, n, mat2str(size(C)));
    end
    
    % Ensure double in [0,1] range
    C = double(C);
    if any(C(:) < 0) || any(C(:) > 1)
        warning('bct:runtime:colormaps:OutOfRange', ...
            'Colormap "%s" has values outside [0,1] range, clamping', id);
        C = max(0, min(1, C));
    end
end

function mustBePositiveInteger(x)
    if ~isempty(x)
        validateattributes(x, {'numeric'}, {'scalar', 'positive', 'integer'});
    end
end
