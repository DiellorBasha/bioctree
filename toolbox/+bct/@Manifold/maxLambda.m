function lmax = maxLambda(obj, scope)
% maxLambda - Get maximum eigenvalue of the Laplacian
%
% Returns the largest eigenvalue (maximum spatial frequency) of the
% Laplacian operator. Can return either the true maximum or the maximum
% from precomputed eigenvalues (if available).
%
% Syntax:
%   lmax = bct.Manifold.maxLambda(obj)
%   lmax = bct.Manifold.maxLambda(obj, scope)
%
% Inputs:
%   obj   - bct.Manifold object with populated Laplacian property
%   scope - (optional) String specifying which maximum to return:
%           'precomputed' - Maximum from obj.Eigenvalues (if available)
%                          Falls back to 'true' if not available
%           'true'        - True maximum via eigs(Laplacian)
%           Default: 'precomputed'
%
% Outputs:
%   lmax - Maximum eigenvalue (spatial frequency bound)
%
% Notes:
%   - Returns empty [] if Laplacian is not computed
%   - 'true' scope uses eigs to compute the largest eigenvalue directly
%   - For normalized Laplacian: lmax ≈ 2.0
%   - For unnormalized Laplacian: lmax depends on mesh geometry
%   - Eigenvalues property must exist and be populated for 'precomputed'
%
% Examples:
%   % Get maximum from precomputed eigenvalues
%   manifold = bct.Manifold(struct('V', V, 'F', F));
%   manifold.Eigenvalues = eigs(manifold.Laplacian, 500, 'sm');
%   lmax = bct.Manifold.maxLambda(manifold);
%   
%   % Force computation of true maximum
%   lmax_true = bct.Manifold.maxLambda(manifold, 'true');
%   
%   % Without precomputed eigenvalues, automatically computes true max
%   manifold2 = bct.Manifold(struct('V', V, 'F', F));
%   lmax2 = bct.Manifold.maxLambda(manifold2);  % Uses eigs
%
% See also: eigs, bct.Lambda.eigenbasis

% Default scope
if nargin < 2
    scope = 'precomputed';
end

% Validate scope
if ~ismember(scope, {'precomputed', 'true'})
    error('maxLambda:InvalidScope', ...
        'scope must be ''precomputed'' or ''true'' (got: %s)', scope);
end

% Check if Laplacian exists
if isempty(obj.Laplacian)
    warning('maxLambda:NoLaplacian', ...
        'Laplacian is not computed. Returning empty.');
    lmax = [];
    return;
end

% Handle precomputed scope
if strcmp(scope, 'precomputed')
    % Check if Eigenvalues property exists and is populated
    if isprop(obj, 'Eigenvalues') && ~isempty(obj.Eigenvalues)
        lmax = max(obj.Eigenvalues);
        return;
    else
        % Fall back to true computation
        warning('maxLambda:NoEigenvalues', ...
            'Eigenvalues not available. Computing true maximum with eigs.');
        scope = 'true';
    end
end

% Compute true maximum using eigs
if strcmp(scope, 'true')
    try
        % Compute largest eigenvalue
        lmax = eigs(obj.Laplacian, 1, 'largestabs');
        lmax = real(lmax);  % Should be real for symmetric Laplacian
    catch ME
        error('maxLambda:EigsFailed', ...
            'Failed to compute maximum eigenvalue: %s', ME.message);
    end
end

end
