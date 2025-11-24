function kernel_fh = laplacian_gaussian()
  % laplacian_gaussian - Returns Laplacian-of-Gaussian (LoG) kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.laplacian_gaussian()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, center, sigma)
  %               Evaluates LoG kernel (normalized second derivative of Gaussian)
  %
  % Description:
  %   Laplacian-of-Gaussian (LoG) kernel - optimal for edge/feature detection.
  %   Also known as Mexican hat when normalized.
  %   
  %   Mathematical form:
  %   LoG(x) = -(1/(sqrt(2π)σ³)) * (1 - (x-c)²/σ²) * exp(-(x-c)²/(2σ²))
  %   
  %   Properties:
  %   - Zero-mean (balanced positive and negative lobes)
  %   - Band-pass characteristic in frequency domain
  %   - Scale-space extrema correspond to features
  %   
  %   Applications:
  %   - Edge detection on Lambda domain (spatial edges)
  %   - Feature extraction on Omega domain (temporal features)
  %   - Blob detection in joint domains
  %   - Multi-scale analysis via sigma scaling
  %
  % Parameters (when evaluating):
  %   x      - Evaluation points [N×1]
  %   center - Center location (scalar)
  %   sigma  - Scale parameter (scalar, sigma > 0)
  %
  % Example (edge detection on Lambda):
  %   log_kernel = bct.filters.kernels.laplacian_gaussian();
  %   lambda = linspace(0, 100, 50);
  %   H = log_kernel(lambda, 50, 10);  % LoG centered at λ=50, σ=10
  %
  % Example (multi-scale feature detection):
  %   scales = [5, 10, 20];
  %   for s = scales
  %     H = log_kernel(lambda, 50, s);
  %     % Detect features at different scales
  %   end
  %
  % See also: bct.filters.Filter, bct.filters.kernels.mexican_hat,
  %           bct.filters.kernels.gaussian
  
  kernel_fh = @(x, center, sigma) laplacian_gaussian_kernel(x, center, sigma);
  
  function h = laplacian_gaussian_kernel(x, center, sigma)
    % Normalized Laplacian-of-Gaussian kernel
    %
    % Form: -(1/(√(2π)σ³)) * (1 - z²) * exp(-z²/2)
    % where z = (x - center) / sigma
    
    z = (x - center) / sigma;
    
    % Normalization constant
    norm_const = 1 / (sqrt(2*pi) * sigma^3);
    
    % LoG formula: second derivative of Gaussian
    h = -norm_const * (1 - z.^2) .* exp(-z.^2 / 2);
  end
end
