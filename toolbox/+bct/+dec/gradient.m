function a1 = gradient(DEC, f0)
%GRADIENT Compute gradient of 0-form (scalar field → vector field)
%
% Syntax:
%   a1 = bct.dec.gradient(DEC, f0)
%
% Inputs:
%   DEC - bct.DEC object
%   f0  - [V×1] 0-form (scalar field on vertices)
%
% Returns:
%   a1 - [E×1] 1-form (edge-based gradient)
%
% Notes:
%   - Gradient is the exterior derivative d0
%   - Returns oriented edge values
%
% See also: bct.dec.d0, bct.dec.divergence

arguments
    DEC (1,1) bct.DEC
    f0 (:,1) double
end

% Gradient is simply the exterior derivative
a1 = bct.dec.d0(DEC) * f0;

end
