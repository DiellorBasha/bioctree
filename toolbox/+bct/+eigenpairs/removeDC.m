function [U, lambda] = removeDC(U, lambda)
%REMOVEDC Remove DC (constant) mode from eigenpairs
%
% Syntax:
%   [U_noDC, lambda_noDC] = bct.eigenpairs.removeDC(U, lambda)
%
% Removes the eigenmode corresponding to the smallest eigenvalue
% (typically the DC/constant mode for Laplace-Beltrami operator)
%
% Inputs:
%   U      - [N×k] eigenvectors
%   lambda - [k×1] eigenvalues
%
% Outputs:
%   U_noDC      - [N×(k-1)] eigenvectors without DC mode
%   lambda_noDC - [(k-1)×1] eigenvalues without DC mode
%
% Notes:
%   - Finds eigenvalue closest to zero
%   - Removes corresponding eigenvector
%   - Reports removed eigenvalue for verification
%
% See also: bct.eigenpairs.fromFEM

arguments
    U      (:,:) double
    lambda (:,1) double
end

% Find DC eigenvalue (closest to zero)
[~, idx0] = min(abs(lambda));
dc_value = lambda(idx0);

% Remove DC mode
mask = true(size(lambda));
mask(idx0) = false;
U = U(:, mask);
lambda = lambda(mask);

fprintf('  Removed DC eigenvalue: %.3e\n', dc_value);

end
