function limits = clim(values)
%BCT.UI.COLOR.CLIM  Compute default color limits from data
%
%   limits = bct.ui.color.clim(values)
%
% Purpose
%   Compute default CLim from finite values for color mapping.
%
% Inputs
%   values - numeric array of any shape
%
% Outputs
%   limits - [1×2] double: [lo hi]
%
% Rules
%   - Uses finite values only
%   - lo = min(finite values), hi = max(finite values)
%   - If no finite values: returns [0 1]
%   - If constant (lo == hi): returns [lo hi] (caller handles midpoint mapping)
%
% See also: bct.ui.color.rgb

    arguments
        values {mustBeNumeric}
    end

    % Extract finite values
    finiteMask = isfinite(values);
    
    if ~any(finiteMask)
        % No finite values - return default
        limits = [0 1];
        return;
    end
    
    finiteVals = values(finiteMask);
    lo = min(finiteVals);
    hi = max(finiteVals);
    
    % Return limits (even if constant)
    limits = [lo hi];
end
