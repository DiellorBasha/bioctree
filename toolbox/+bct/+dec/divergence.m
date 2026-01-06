function f0 = divergence(DEC, U)
%DIVERGENCE Compute divergence of vector field or 1-form
%
% Syntax:
%   f0 = bct.dec.divergence(DEC, U)
%
% Inputs:
%   DEC - bct.DEC object
%   U   - [F×3] dual vector field OR
%         [V×3] primal vector field OR
%         [E×1] primal 1-form OR
%         [E×1] dual 1-form
%
% Returns:
%   f0 - [V×1] primal 0-form (vertex-based divergence) OR
%        [F×1] dual 0-form (face-based divergence)
%
% Notes:
%   - Simple wrapper around DiscreteExteriorCalculus.divergence
%   - Automatically converts vector fields to 1-forms if needed
%   - Uses 'primal' route by default (primal 1-form → primal 0-form)
%
% See also: bct.dec.gradient, bct.dec.curl, DiscreteExteriorCalculus

arguments
    DEC (1,1) bct.DEC
    U double
end

% Delegate to DiscreteExteriorCalculus backend
Backend = DEC.backend();
f0 = Backend.divergence(U, 'primal');

end
