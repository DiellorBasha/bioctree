function y = applySpectral(E, x, k, opts)
%BCT.FILTER.APPLYSPECTRAL Apply spectral filter to signal using eigenpairs
%
% Syntax:
%   y = bct.filter.applySpectral(E, x, k)
%   y = bct.filter.applySpectral(E, x, k, opts)
%
% Inputs:
%   E - bct.Eigenpairs object
%   x - Input signal [N×1] or [N×T] for multiple signals
%   k - Bound unary kernel handle: w = k(lambda)
%   opts - Options struct (optional)
%
% Options:
%   K                - Truncation rank (default: E.numModes())
%   NormalizeWeights - "none"|"l1"|"l2"|"max" (default: "none")
%   AllowComplex     - Allow complex weights/outputs (default: true)
%   BatchSize        - Block size for large T (default: inf)
%   CheckDimensions  - Validate dimensions (default: true)
%
% Outputs:
%   y - Filtered signal, same size as x
%
% Description:
%   Applies a spectral filter using the eigenpair decomposition:
%   
%     y = U * (w .* (U' * M * x))
%   
%   where:
%     - U are eigenvectors
%     - w = k(lambda) are kernel weights
%     - M is the inner product matrix
%
%   The function uses Eigenpairs' project/reconstruct methods when
%   available for optimal performance and correctness.
%
% Example:
%   % Create filtered signal using Heat kernel
%   E = M.FEM().eigenpairs(100);
%   k = bct.kernel.bind("Heat", struct("tau", 0.05));
%   y = bct.filter.applySpectral(E, x, k);
%
% See also: bct.kernel.bind, bct.Eigenpairs

arguments
    E (1,1) bct.Eigenpairs
    x (:,:) double
    k (1,1) function_handle
    opts.K (1,1) {mustBePositive, mustBeInteger} = E.numModes()
    opts.NormalizeWeights (1,1) string {mustBeMember(opts.NormalizeWeights, ["none","l1","l2","max"])} = "none"
    opts.AllowComplex (1,1) logical = true
    opts.BatchSize (1,1) {mustBePositive} = inf
    opts.CheckDimensions (1,1) logical = true
end

% Validate dimensions
N = E.domainSize();
if opts.CheckDimensions
    if size(x, 1) ~= N
        error('bct:filter:SizeMismatch', ...
            'Signal size [%d×%d] does not match eigenpair domain size [%d]', ...
            size(x,1), size(x,2), N);
    end
end

% Ensure K does not exceed available modes
K = min(opts.K, E.numModes());

% Compute kernel weights
lambda = E.Values(1:K);
w = k(lambda);

% Validate weight dimensions
if numel(w) ~= K
    error('bct:filter:KernelWeightSizeMismatch', ...
        'Kernel returned %d weights but expected %d', numel(w), K);
end

% Check for complex weights
if ~opts.AllowComplex && ~isreal(w)
    error('bct:filter:ComplexWeightsNotAllowed', ...
        'Kernel produced complex weights but AllowComplex=false');
end

% Normalize weights if requested
w = normalizeWeights(w(:), opts.NormalizeWeights);

% Get number of signals
T = size(x, 2);

% Determine batch processing
if T > opts.BatchSize
    % Block processing for large signal sets
    num_batches = ceil(T / opts.BatchSize);
    y = zeros(N, T);
    
    for b = 1:num_batches
        idx_start = (b-1)*opts.BatchSize + 1;
        idx_end = min(b*opts.BatchSize, T);
        idx = idx_start:idx_end;
        
        y(:, idx) = filterBlock(E, x(:,idx), w, K);
    end
else
    % Single-pass filtering
    y = filterBlock(E, x, w, K);
end

% Check for complex output
if ~opts.AllowComplex && ~isreal(y)
    warning('bct:filter:ComplexOutput', ...
        'Filter produced complex output. Taking real part.');
    y = real(y);
end

end

%% Helper Functions

function y = filterBlock(E, x, w, K)
%FILTERBLOCK Apply filter to a block of signals
%
% Uses Eigenpairs' project/reconstruct methods when available

% Project to spectral domain
% Preferred: use E.project() which handles inner product correctly
coeffs = E.project(x);

% Truncate to K modes
coeffs = coeffs(1:K, :);

% Apply weights
coeffs_filtered = w .* coeffs;

% Reconstruct
% Use E.reconstruct() if available, otherwise manual reconstruction
if hasMethod(E, 'reconstruct')
    % Pad coefficients back to full size if needed
    if K < E.numModes()
        coeffs_full = zeros(E.numModes(), size(coeffs, 2));
        coeffs_full(1:K, :) = coeffs_filtered;
        y = E.reconstruct(coeffs_full);
    else
        y = E.reconstruct(coeffs_filtered);
    end
else
    % Manual reconstruction
    U = E.Vectors(:, 1:K);
    y = U * coeffs_filtered;
end

end

function w_norm = normalizeWeights(w, method)
%NORMALIZEWEIGHTS Normalize kernel weights

switch method
    case "none"
        w_norm = w;
    case "l1"
        w_norm = w / sum(abs(w));
    case "l2"
        w_norm = w / norm(w, 2);
    case "max"
        w_norm = w / max(abs(w));
    otherwise
        w_norm = w;
end

end

function tf = hasMethod(obj, methodName)
%HASMETHOD Check if object has a specific method

mc = metaclass(obj);
tf = any(strcmp({mc.MethodList.Name}, methodName));

end
