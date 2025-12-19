function L = laplacian1(DEC)
%LAPLACIAN1 Compute 1-form Laplacian operator
%
% Syntax:
%   L = bct.dec.laplacian1(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   L - [E×E] sparse 1-form Laplacian matrix
%
% Notes:
%   - Laplacian for edge-based 1-forms (vector fields)
%   - Constructed as: L = d1' * star2 * d1 + star1^(-1) * d0 * star0 * d0' * star1
%   - Hodge Laplacian: Δ = dδ + δd
%
% See also: bct.dec.laplacian0, bct.dec.laplacian2

arguments
    DEC (1,1) bct.DEC
end

% 1-form Laplacian (Hodge Laplacian)
% Δ₁ = d1' * star2 * d1 + star1^(-1) * d0 * star0 * d0' * star1
d0 = bct.dec.d0(DEC);
d1 = bct.dec.d1(DEC);
star0 = bct.dec.star0(DEC);
star1 = bct.dec.star1(DEC);
star2 = bct.dec.star2(DEC);

% Compute both terms
term1 = d1' * star2 * d1;               % δd part (codifferential of derivative)
term2 = d0 * (star0 * (d0' * star1));   % dδ part (derivative of codifferential)

L = term1 + term2;

end
