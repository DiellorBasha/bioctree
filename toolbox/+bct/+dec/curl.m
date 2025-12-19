function a2 = curl(DEC, a1)
%CURL Compute curl of 1-form (vector field → scalar curl / 2-form)
%
% Syntax:
%   a2 = bct.dec.curl(DEC, a1)
%
% Inputs:
%   DEC - bct.DEC object
%   a1  - [E×1] 1-form (edge-based vector field)
%
% Returns:
%   a2 - [F×1] 2-form (face-based curl / scalar curl)
%
% Notes:
%   - Curl is the exterior derivative d1
%   - Maps 1-forms to 2-forms (face values)
%   - In 2D, curl is a scalar per face
%
% See also: bct.dec.d1, bct.dec.gradient, bct.dec.divergence

arguments
    DEC (1,1) bct.DEC
    a1 (:,1) double
end

% Curl is the exterior derivative d1
a2 = bct.dec.d1(DEC) * a1;

end
