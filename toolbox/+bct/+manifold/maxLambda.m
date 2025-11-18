function lambda_max = maxLambda(M, scope)
%MANIFOLD_LAMBDA_MAX Get the maximum Laplacian eigenvalue from a Manifold.
%
%   lambda_max = bct.util.manifold_lambda_max(M)
%   lambda_max = bct.util.manifold_lambda_max(M, scope)
%
%   INPUTS
%   ------
%   M     : bct.manifold.Manifold object
%   scope : 'basis' (default) or 'full'
%
%       'basis' :
%           Use the largest eigenvalue among M.Eigenvalues
%           (i.e. max over the modes you have computed, e.g. 599 modes).
%
%       'full'  :
%           Use M.MaxResolutionFull.lambda_max_full
%           (requires you to have called M.computeMaxResolutionFull(L)
%            beforehand to populate MaxResolutionFull).
%
%   OUTPUT
%   ------
%   lambda_max : scalar, maximum eigenvalue (1/m^2 if coordinates are in m)
%
%   NOTES
%   -----
%   - Units depend on the units of M.V:
%       * If vertices are in meters: lambda_max in 1/m^2.
%       * If vertices are in mm    : lambda_max in 1/mm^2.
%
%   EXAMPLES
%   --------
%       % Max over current basis (e.g. 599 modes)
%       lam_basis = bct.util.manifold_lambda_max(B.Manifold, 'basis');
%
%       % Max over full operator (after computeMaxResolutionFull)
%       lam_full  = bct.util.manifold_lambda_max(B.Manifold, 'full');

    if nargin < 2
        scope = 'basis';
    end

    switch lower(scope)
        case 'basis'
            if isempty(M.Eigenvalues)
                error('manifold_lambda_max: Manifold.Eigenvalues is empty.');
            end
            lambda_max = max(M.Eigenvalues(:));

        case 'full'
            if isempty(M.MaxResolutionFull) || ...
               ~isfield(M.MaxResolutionFull, 'lambda_max_full')
                error(['manifold_lambda_max: MaxResolutionFull.lambda_max_full ' ...
                       'not set. Call Manifold.computeMaxResolutionFull(L) first.']);
            end
            lambda_max = M.MaxResolutionFull.lambda_max_full;

        otherwise
            error('manifold_lambda_max: Unknown scope "%s". Use "basis" or "full".', scope);
    end
end
