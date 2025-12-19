function L = laplacian2(DEC)
%LAPLACIAN2 Compute 2-form Laplacian operator
%
% Syntax:
%   L = bct.dec.laplacian2(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   L - [F×F] sparse 2-form Laplacian matrix
%
% Notes:
%   - Laplacian for face-based 2-forms (densities)
%   - Constructed as: L = d1 * star1^(-1) * d1' * star2
%   - In 2D manifolds, this is δd (no dδ term since d2 = 0)
%
% See also: bct.dec.laplacian0, bct.dec.laplacian1

arguments
    DEC (1,1) bct.DEC
end

% 2-form Laplacian
% Δ₂ = d1 * star1^(-1) * d1' * star2 (only δd term for top forms)
d1 = bct.dec.d1(DEC);
star1 = bct.dec.star1(DEC);
star2 = bct.dec.star2(DEC);

% Note: star1^(-1) would require sparse inverse, which can be unstable
% Better to compute via: d1 * (star1 \ (d1' * star2))
% But for now, explicit form:
L = d1 * (star1 \ (d1' * star2));

end
