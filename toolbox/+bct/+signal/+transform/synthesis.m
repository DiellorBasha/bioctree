function x = synthesis(x_hat, manifold)
    %SYNTHESIS Inverse transform: reconstruct signal from spectral coefficients
    %
    %   x = bct.signal.transform.synthesis(x_hat, manifold) reconstructs signal
    %   from spectral coefficients using the manifold's eigenmode basis.
    %
    %   Computes: x = U * x_hat
    %
    %   where U are the eigenvectors (Fourier basis) of the manifold.
    %
    %   Inputs:
    %     x_hat    - Spectral coefficients [k×1] or [k×T]
    %     manifold - bct.manifold.Manifold object with computed eigenmodes
    %
    %   Returns:
    %     x - Reconstructed signal on vertices [N×1] or [N×T]
    %
    %   Example:
    %     % Forward transform
    %     x_hat = bct.signal.transform.analysis(x, B.Manifold);
    %     
    %     % Modify spectral coefficients
    %     x_hat_filtered = x_hat .* filter_kernel;
    %     
    %     % Inverse transform
    %     x_reconstructed = bct.signal.transform.synthesis(x_hat_filtered, B.Manifold);
    %
    %   See also: bct.signal.transform.analysis, bct.signal.transform.filter
    
    % Validate manifold
    if ~isa(manifold, 'bct.manifold.Manifold')
        error('bct:transform:synthesis:InvalidManifold', ...
            'manifold must be a bct.manifold.Manifold object');
    end
    
    % Get eigenvectors
    U = manifold.Eigenvectors;
    
    if isempty(U)
        error('bct:transform:synthesis:NoEigenvectors', ...
            'No eigenvectors computed. Call Manifold.meshFourier() first.');
    end
    
    % Validate spectral coefficient dimensions
    k = size(U, 2);
    if size(x_hat, 1) ~= k
        error('bct:transform:synthesis:SizeMismatch', ...
            'Spectral coefficients size (%d) must match number of modes (%d)', ...
            size(x_hat, 1), k);
    end
    
    % Reconstruct signal
    x = U * x_hat;
end
