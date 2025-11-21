function lambda_max_est = estimateLambdaMax(obj)
% estimateLambdaMax - Estimate maximum eigenvalue of Laplacian using Gershgorin Circle theorem
%
% Uses Gershgorin Circle theorem to provide a rigorous upper bound
% on the maximum eigenvalue. This avoids costly eigendecomposition
% during construction.
%
% For symmetric positive semi-definite matrix L:
%   λ_max ≤ max_i ( L_ii + Σ_{j≠i} |L_ij| )
%
% For normalized Laplacian (cotangent-normalized):
%   λ_max ≤ 2  (well-known theoretical bound)
%
% The estimate is used to initialize the dual Lambda domain.
% The true maximum will be computed when Lambda eigenvalues are
% calculated via meshFourier.
%
% Syntax:
%   lambda_max_est = obj.estimateLambdaMax()
%
% Inputs:
%   obj - bct.Manifold object with computed Laplacian
%
% Outputs:
%   lambda_max_est - Upper bound estimate of maximum eigenvalue
%
% Examples:
%   manifold = bct.Manifold(struct('V', V, 'F', F));
%   lmax_est = manifold.estimateLambdaMax();
%   
%   % For normalized Laplacian, returns exact theoretical bound
%   manifold_norm = bct.Manifold(struct('V', V, 'F', F), 'cotangent-normalized');
%   lmax_est_norm = manifold_norm.estimateLambdaMax();  % Returns 2.0
%
% See also: maxLambda, meshFourier

if strcmp(obj.LaplacianType, 'cotangent-normalized')
    % For normalized Laplacian: eigenvalues ∈ [0, 2]
    lambda_max_est = 2.0;
else
    % For cotangent Laplacian: use Gershgorin Circle theorem
    % λ_max ≤ max_i ( L_ii + Σ_{j≠i} |L_ij| )
    L = obj.Laplacian;
    
    % VECTORIZED computation (much faster than loop)
    % For each row: diagonal + sum of absolute values of off-diagonal elements
    % Since L is symmetric and sparse, we can use:
    %   row_sum = sum(abs(L), 2)  % sum of absolute values in each row
    %   gershgorin_bound = diag(L) + (row_sum - abs(diag(L)))
    % Simplifies to:
    %   gershgorin_bound = 2 * row_sum - diag(L)
    % But for symmetric L with non-negative off-diagonals (cotangent can have negatives),
    % we need: diag(L) + sum(abs(off-diagonal))
    
    % Get diagonal
    d = diag(L);
    
    % Sum of absolute values in each row
    row_abs_sum = full(sum(abs(L), 2));
    
    % Gershgorin bound for each row: L_ii + Σ_{j≠i} |L_ij|
    % = L_ii + (row_abs_sum - |L_ii|)
    gershgorin_bounds = d + (row_abs_sum - abs(d));
    
    % Maximum over all rows gives the upper bound
    lambda_max_est = max(gershgorin_bounds);
end

end
