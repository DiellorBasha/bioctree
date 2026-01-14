function Y = analysis(mft, imft, X, filterOrWeights, options)
%BCT.FILTER.ANALYSIS  Apply filterbank to signal and return subband signals
%
%   Y = bct.filter.analysis(mft, imft, X, F)
%   Y = bct.filter.analysis(mft, imft, X, weights)
%
% Purpose
%   Applies each filter in a filterbank to a signal and returns subband
%   signals (one per filter). This is the "filtering analysis operator"
%   that decomposes a signal into filtered components.
%
% Inputs
%   mft     - [k×N] forward transform operator from bct.manifold.operator.mft
%   imft    - [N×k] inverse transform operator from bct.manifold.operator.imft
%   X       - [N×T] or [N×1] vertex-domain signal
%             N = number of vertices, T = time samples (default 1)
%   F       - Filter struct from bct.filter.design
%      OR
%   weights - [k×J] spectral weights matrix (J = number of filters)
%
% Name-Value Arguments
%   OutputFormat - "stack" (default) | "cell"
%                  "stack": return [N×T×J] array (or [N×T] if J=1)
%                  "cell":  return {1×J} cell array, each [N×T]
%   Strict       - logical (default true), enforce validation
%
% Output
%   Y - Subband signals
%       If OutputFormat="stack": [N×T×J] (or [N×T] if J=1)
%       If OutputFormat="cell":  {1×J} cell, each [N×T]
%
% Algorithm
%   For each filter j=1:J:
%     1. C = mft * X              (forward transform to spectral domain)
%     2. Cj = weights(:,j) .* C   (apply filter j weights)
%     3. Yj = imft * Cj           (inverse transform to vertex domain)
%
%   The forward transform is computed once and reused for all filters.
%
% Validation (Strict=true)
%   - size(mft,2) == size(X,1) == size(imft,1) (N compatibility)
%   - size(mft,1) == size(imft,2) (k compatibility)
%   - size(weights,1) == k
%   - All weights finite
%
% Examples
%   % Single filter (J=1)
%   M = bct.manifold.load();
%   E = M.eigenmodes(100);
%   F = bct.filter.design(E.values, "Heat", "tau", 10);
%   
%   mft_op = bct.manifold.operator.mft(M);
%   imft_op = bct.manifold.operator.imft(M);
%   signal = randn(M.nVertices, 1);
%   
%   filtered = bct.filter.analysis(mft_op, imft_op, signal, F);  % [N×T]
%
%   % Filterbank (J=4)
%   taus = [1 10 25 50];
%   F = bct.filter.design(E.values, "Heat", "tau", taus);
%   subbands = bct.filter.analysis(mft_op, imft_op, signal, F);  % [N×T×4]
%
%   % Cell output format
%   subbands = bct.filter.analysis(mft_op, imft_op, signal, F, ...
%       "OutputFormat", "cell");  % {1×4} cell
%
%   % Multiple time samples
%   signals = randn(M.nVertices, 50);  % 50 time points
%   subbands = bct.filter.analysis(mft_op, imft_op, signals, F);  % [N×50×4]
%
% See also: bct.filter.synthesis, bct.filter.design, bct.manifold.operator.mft

arguments
    mft {mustBeNumeric, mustBeReal}
    imft {mustBeNumeric, mustBeReal}
    X {mustBeNumeric}
    filterOrWeights  % struct or [k×J] numeric
    options.OutputFormat (1,1) string {mustBeMember(options.OutputFormat, ["stack", "cell"])} = "stack"
    options.Strict (1,1) logical = true
end

%% Extract weights from filter struct or use directly
if isstruct(filterOrWeights)
    weights = filterOrWeights.weights;
else
    weights = filterOrWeights;
end

% Determine number of filters
[k_weights, J] = size(weights);

%% Coerce X to [N×T]
if isvector(X)
    X = X(:);  % Column vector [N×1]
end
[N, T] = size(X);

%% Validation (Strict mode)
if options.Strict
    % Validate operator dimensions
    [k_mft, N_mft] = size(mft);
    [N_imft, k_imft] = size(imft);
    
    if ~ismatrix(mft) || isvector(mft)
        error('bct:filter:analysis:InvalidMFT', ...
            'Forward transform "mft" must be a 2D matrix [k×N].');
    end
    
    if ~ismatrix(imft) || isvector(imft)
        error('bct:filter:analysis:InvalidIMFT', ...
            'Inverse transform "imft" must be a 2D matrix [N×k].');
    end
    
    if ~ismatrix(X)
        error('bct:filter:analysis:InvalidData', ...
            'Input data "X" must be 2D matrix [N×T] or vector [N×1].');
    end
    
    % Check N compatibility
    if N_mft ~= N || N_imft ~= N
        error('bct:filter:analysis:DimensionMismatch', ...
            ['N mismatch: mft expects N=%d, imft expects N=%d, X has N=%d.\n' ...
             'mft: [%d×%d], imft: [%d×%d], X: [%d×%d]'], ...
            N_mft, N_imft, N, k_mft, N_mft, N_imft, k_imft, N, T);
    end
    
    % Check k compatibility
    if k_mft ~= k_imft || k_mft ~= k_weights
        error('bct:filter:analysis:DimensionMismatch', ...
            ['k mismatch: mft has k=%d, imft has k=%d, weights has k=%d.\n' ...
             'mft: [%d×%d], imft: [%d×%d], weights: [%d×%d]'], ...
            k_mft, k_imft, k_weights, k_mft, N_mft, N_imft, k_imft, k_weights, J);
    end
    
    % Validate weights are finite
    if any(~isfinite(weights(:)))
        error('bct:filter:analysis:NonFiniteWeights', ...
            'Filter weights contain non-finite values (NaN or Inf).');
    end
end

%% Core computation: forward transform (computed once)
C = mft * X;  % [k×T]

%% Apply each filter and compute subband signals
if strcmp(options.OutputFormat, "cell")
    % Cell output: {1×J}
    Y = cell(1, J);
    for j = 1:J
        Cj = weights(:, j) .* C;  % [k×T] element-wise multiply
        Y{j} = imft * Cj;         % [N×T]
    end
else
    % Stack output: [N×T×J]
    if J == 1
        % Special case: single filter returns [N×T] not [N×T×1]
        Cj = weights(:, 1) .* C;
        Y = imft * Cj;
    else
        Y = zeros(N, T, J);
        for j = 1:J
            Cj = weights(:, j) .* C;
            Y(:, :, j) = imft * Cj;
        end
    end
end

end
