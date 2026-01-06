function a2 = curl(DEC, U)
%CURL Compute curl of vector field or 1-form
%
% Syntax:
%   a2 = bct.dec.curl(DEC, U)
%
% Inputs:
%   DEC - bct.DEC object
%   U   - [F×3] dual vector field OR
%         [V×3] primal vector field OR
%         [E×1] primal 1-form OR
%         [E×1] dual 1-form
%
% Returns:
%   a2 - [F×1] primal 2-form (face-based curl) OR
%        [V×1] dual 2-form (vertex-based curl)
%
% Notes:
%   - Simple wrapper around DiscreteExteriorCalculus.curl
%   - Automatically converts vector fields to 1-forms if needed
%   - Uses 'primal' route by default (primal 1-form → primal 2-form)
%   - In 2D, curl is a scalar per face
%
% See also: bct.dec.gradient, bct.dec.divergence, DiscreteExteriorCalculus

arguments
    DEC (1,1) bct.DEC
    U double
end

% Delegate to DiscreteExteriorCalculus backend
Backend = DEC.backend();
a2 = Backend.curl(U, 'primal');

end
