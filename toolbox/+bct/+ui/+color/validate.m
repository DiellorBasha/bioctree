function validate(spec)
%BCT.UI.COLOR.VALIDATE  Validate ColorSpec structure
%
%   bct.ui.color.validate(spec)
%
% Purpose
%   Ensures ColorSpec structure is well-formed. Throws errors on violations.
%
% Inputs
%   spec - struct with fields: Colormap, NColors, CLim, NaNColor
%
% Validation Rules (v1)
%   - spec.Colormap is string scalar
%   - spec.NColors is positive integer scalar
%   - spec.NaNColor is 1×3 double in [0,1]
%   - if spec.CLim non-empty: size is 1×2, CLim(1) <= CLim(2)
%
% Errors
%   bct:ui:color:InvalidColormap - if Colormap field invalid
%   bct:ui:color:InvalidNColors - if NColors field invalid
%   bct:ui:color:InvalidNaNColor - if NaNColor field invalid
%   bct:ui:color:InvalidCLim - if CLim field invalid
%
% Notes
%   Existence of colormap ID is validated in resolve() (execution layer).
%
% See also: bct.ui.color.schema, bct.ui.color.rgb

    % Validate Colormap
    if ~isfield(spec, 'Colormap') || ~isstring(spec.Colormap) && ~ischar(spec.Colormap)
        error('bct:ui:color:InvalidColormap', ...
            'spec.Colormap must be a string or char');
    end
    if ~isscalar(string(spec.Colormap))
        error('bct:ui:color:InvalidColormap', ...
            'spec.Colormap must be scalar string');
    end

    % Validate NColors
    if ~isfield(spec, 'NColors')
        error('bct:ui:color:InvalidNColors', ...
            'spec.NColors is required');
    end
    if ~isnumeric(spec.NColors) || ~isscalar(spec.NColors) || ...
            spec.NColors <= 0 || mod(spec.NColors, 1) ~= 0
        error('bct:ui:color:InvalidNColors', ...
            'spec.NColors must be a positive integer scalar');
    end

    % Validate NaNColor
    if ~isfield(spec, 'NaNColor')
        error('bct:ui:color:InvalidNaNColor', ...
            'spec.NaNColor is required');
    end
    if ~isnumeric(spec.NaNColor) || ~isequal(size(spec.NaNColor), [1 3])
        error('bct:ui:color:InvalidNaNColor', ...
            'spec.NaNColor must be 1×3 numeric');
    end
    if any(spec.NaNColor < 0) || any(spec.NaNColor > 1)
        error('bct:ui:color:InvalidNaNColor', ...
            'spec.NaNColor values must be in [0,1]');
    end

    % Validate CLim
    if ~isfield(spec, 'CLim')
        error('bct:ui:color:InvalidCLim', ...
            'spec.CLim is required');
    end
    if ~isempty(spec.CLim)
        if ~isnumeric(spec.CLim) || ~isequal(size(spec.CLim), [1 2])
            error('bct:ui:color:InvalidCLim', ...
                'spec.CLim must be [] or [1×2] numeric');
        end
        if spec.CLim(1) > spec.CLim(2)
            error('bct:ui:color:InvalidCLim', ...
                'spec.CLim(1) must be <= CLim(2), got [%.3f, %.3f]', ...
                spec.CLim(1), spec.CLim(2));
        end
    end
end
