function cmap = resolve(colormapId, n)
%BCT.UI.COLOR.RESOLVE  Resolve colormap ID to Nx3 array
%
%   cmap = bct.ui.color.resolve(colormapId, n)
%
% Purpose
%   Resolves a colormap ID to an [n×3] colormap matrix using the
%   runtime dictionary.
%
% Inputs
%   colormapId - string scalar, colormap identifier
%   n          - positive integer, number of colors
%
% Outputs
%   cmap       - [n×3] double in [0,1]
%
% Behavior
%   1. Retrieves runtime dictionary: bct.runtime.colormap()
%   2. Looks up generator function: D(colormapId)
%   3. Calls generator: cmap = generator(n)
%   4. Validates output shape and range
%
% Errors
%   bct:ui:color:UnknownColormap - if colormapId not in dictionary
%   bct:ui:color:InvalidColormapOutput - if generator output is invalid
%
% See also: bct.runtime.colormap, bct.ui.color.rgb

    arguments
        colormapId (1,1) string
        n (1,1) double {mustBePositive, mustBeInteger}
    end

    % Get runtime dictionary
    D = bct.runtime.colormap();

    % Check if colormap exists
    if ~isKey(D, colormapId)
        error('bct:ui:color:UnknownColormap', ...
            'Unknown colormap ID: "%s". Available colormaps: %s', ...
            colormapId, strjoin(string(keys(D)), ', '));
    end

    % Call generator
    generator = D(colormapId);
    try
        cmap = generator(n);
    catch ME
        error('bct:ui:color:InvalidColormapOutput', ...
            'Colormap generator "%s" threw error: %s', ...
            colormapId, ME.message);
    end

    % Validate output
    if ~isnumeric(cmap) || size(cmap, 2) ~= 3 || size(cmap, 1) ~= n
        error('bct:ui:color:InvalidColormapOutput', ...
            'Colormap "%s" must return [%d×3] numeric array, got [%s]', ...
            colormapId, n, mat2str(size(cmap)));
    end

    % Ensure double
    cmap = double(cmap);

    % Validate range (allow small numerical drift)
    if any(cmap(:) < -1e-6) || any(cmap(:) > 1 + 1e-6)
        error('bct:ui:color:InvalidColormapOutput', ...
            'Colormap "%s" values must be in [0,1], got range [%.3f, %.3f]', ...
            colormapId, min(cmap(:)), max(cmap(:)));
    end

    % Clamp to [0,1]
    cmap = max(0, min(1, cmap));
end
