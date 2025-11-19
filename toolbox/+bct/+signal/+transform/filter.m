function y = filter(x, filt)
    %FILTER Apply spectral filter to signal
    %
    %   y = bct.signal.transform.filter(x, filt) filters signal x using the
    %   spectral filter filt.
    %
    %   Workflow:
    %     1. Project signal onto eigenmodes: x_hat(λ_k) = U' * x
    %     2. Multiply by filter kernel: y_hat(λ_k) = g(λ_k) * x_hat(λ_k)
    %     3. Reconstruct: y = U * y_hat
    %
    %   Inputs:
    %     x    - Signal on manifold vertices [N×1] or [N×T]
    %     filt - bct.filters.Filter object
    %
    %   Returns:
    %     y    - Filtered signal [N×1] or [N×T]
    %
    %   Example:
    %     % Design bandpass filter
    %     filt = bct.filters.Filter(B.Manifold);
    %     filt.setBand([5, 50], bct.resolution.Quantity.wavelength);
    %     filt.design('band', 'taper', 'hann');
    %     
    %     % Filter signal
    %     y = bct.signal.transform.filter(x, filt);
    %
    %   See also: bct.filters.Filter, bct.signal.transform.analysis, bct.signal.transform.synthesis
    
    % Validate inputs
    if ~isa(filt, 'bct.filters.Filter')
        error('bct:transform:filter:InvalidFilter', ...
            'filt must be a bct.filters.Filter object');
    end
    
    if isempty(filt.g_lambda)
        error('bct:transform:filter:NoFilter', ...
            'Filter not designed. Call filt.design() first.');
    end
    
    % Get eigenvectors and filter response
    U = filt.Manifold.Eigenvectors;
    g = filt.g_lambda;
    
    if isempty(U)
        error('bct:transform:filter:NoEigenvectors', ...
            'No eigenvectors computed. Call Manifold.meshFourier() first.');
    end
    
    % Validate signal dimensions
    N = size(U, 1);
    if size(x, 1) ~= N
        error('bct:transform:filter:SizeMismatch', ...
            'Signal size (%d) must match number of vertices (%d)', size(x, 1), N);
    end
    
    % Analysis: Project signal onto eigenmodes
    x_hat = bct.signal.transform.analysis(x, filt.Manifold);
    
    % Apply filter in spectral domain
    y_hat = bsxfun(@times, g, x_hat);
    
    % Synthesis: Reconstruct filtered signal
    y = bct.signal.transform.synthesis(y_hat, filt.Manifold);
end
