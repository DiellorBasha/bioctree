function f0 = divergence(DEC, a1)
%DIVERGENCE Compute divergence of 1-form (vector field → scalar field)
%
% Syntax:
%   f0 = bct.dec.divergence(DEC, a1)
%
% Inputs:
%   DEC - bct.DEC object
%   a1  - [E×1] 1-form (edge-based vector field)
%
% Returns:
%   f0 - [V×1] 0-form (vertex-based divergence)
%
% Notes:
%   - Divergence is the codifferential: δ = ⋆d⋆
%   - Implemented as: -d0' * star1 (adjoint of gradient)
%
% See also: bct.dec.gradient, bct.dec.curl

arguments
    DEC (1,1) bct.DEC
    a1 (:,1) double
end

% Divergence is the adjoint of gradient under Hodge star
% div = -d0' * star1
d0 = bct.dec.d0(DEC);
star1 = bct.dec.star1(DEC);

f0 = -d0' * (star1 * a1);

end
