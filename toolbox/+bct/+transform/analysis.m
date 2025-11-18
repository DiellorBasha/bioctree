function x_hat = analysis(x, manifold)
    %ANALYSIS Forward transform: project signal onto eigenmodes
    %
    %   x_hat = bct.transform.analysis(x, manifold) projects signal x
    %   onto the manifold's eigenmode basis.
    %
    %   Computes: x_hat(λ_k) = U' * x
    %
    %   where U are the eigenvectors (Fourier basis) of the manifold.
    %
    %   Inputs:
    %     x        - Signal on vertices [N×1] or [N×T]
    %     manifold - bct.manifold.Manifold object with computed eigenmodes
    %
    %   Returns:
    %     x_hat - Spectral coefficients [k×1] or [k×T]
    %             where k is the number of computed modes
    %
    %   Example:
    %     B.Manifold.meshFourier(600);
    %     x_hat = bct.transform.analysis(x, B.Manifold);
    %
    %   See also: bct.transform.synthesis, bct.transform.filter
    
    % Validate manifold
    if ~isa(manifold, 'bct.manifold.Manifold')
        error('bct:transform:analysis:InvalidManifold', ...
            'manifold must be a bct.manifold.Manifold object');
    end
    
    % Get eigenvectors
    U = manifold.Eigenvectors;
    
    if isempty(U)
        error('bct:transform:analysis:NoEigenvectors', ...
            'No eigenvectors computed. Call Manifold.meshFourier() first.');
    end
    
    % Validate signal dimensions
    N = size(U, 1);
    if size(x, 1) ~= N
        error('bct:transform:analysis:SizeMismatch', ...
            'Signal size (%d) must match number of vertices (%d)', size(x, 1), N);
    end
    
    % Project onto eigenmodes
    x_hat = U' * x;
end
