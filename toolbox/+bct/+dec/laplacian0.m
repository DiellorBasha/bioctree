function L = laplacian0(DEC)
%LAPLACIAN0 Compute 0-form Laplacian operator
%
% Syntax:
%   L = bct.dec.laplacian0(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   L - [V×V] sparse 0-form Laplacian matrix
%
% Notes:
%   - Laplacian for scalar functions on vertices
%   - Constructed as: L = d0' * star1 * d0
%   - This is the discrete Laplace-Beltrami operator
%   - Negative semi-definite (convention: Δf = -div(grad(f)))
%
% See also: bct.dec.laplacian1, bct.dec.gradient, bct.dec.divergence

arguments
    DEC (1,1) bct.DEC
end

% 0-form Laplacian: Δ = δd = d0' * star1 * d0
d0 = bct.dec.d0(DEC);
star1 = bct.dec.star1(DEC);

L = d0' * star1 * d0;

end
