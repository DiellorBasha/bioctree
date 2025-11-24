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
% calculated via bct.Lambda.eigenbasis().
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
% See also: maxLambda, bct.Lambda.eigenbasis

if strcmp(obj.LaplacianType, 'cotangent-normalized')
    % For normalized Laplacian: eigenvalues ∈ [0, 2]
    lambda_max_est = 2.0;
else
    % For cotangent Laplacian: use Gershgorin Circle theorem
    % λ_max ≤ max_i ( Σ_j |K_ij| / M_ii )
    % 
    % The cotangent Laplacian is L = M^(-1) * K
    % So we need to estimate eigenvalues of M^(-1) * K
    
    K = obj.CotangentMatrix;
    M = obj.MassMatrix;
    
    % Extract diagonal of mass matrix
    diagM = full(diag(M));
    
    % Safety check
    if any(diagM <= 0)
        error('Mass matrix has non-positive diagonal entries — cannot estimate λ_max.');
    end
    
    % Compute row sums of absolute values of K
    % sum(|K_ij|) over each row i
    rowAbsSum = full(sum(abs(K), 2));
    
    % Gershgorin estimate: max( sum_j |K_ij| / M_ii )
    lambda_max_est = max(rowAbsSum ./ diagM);
end

end
