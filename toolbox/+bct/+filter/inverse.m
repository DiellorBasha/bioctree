function X = inverse(mft, imft, Y, filterOrWeights, options)
%BCT.FILTER.INVERSE  Reconstruct signal from subbands using dual filterbank
%
%   X = bct.filter.inverse(mft, imft, Y, F)
%   X = bct.filter.inverse(mft, imft, Y, weights)
%
% Purpose
%   Reconstructs a signal from subband signals using the DUAL FILTERBANK
%   derived from the analysis weights. This provides stable (near-identity)
%   reconstruction by using canonical dual weights.
%
% Inputs
%   mft     - [k×N] forward transform operator from bct.manifold.operator.mft
%   imft    - [N×k] inverse transform operator from bct.manifold.operator.imft
%   Y       - Subband signals in one of these formats:
%             [N×T×J] stacked array (or [N×T] if J=1)
%             {1×J} cell array, each [N×T]
%   F       - Filter struct from bct.filter.design
%      OR
%   weights - [k×J] spectral weights matrix
%
% Name-Value Arguments
%   InputFormat - "auto" (default) | "stack" | "cell"
%                 "auto": detect from input type
%   Strict      - logical (default true), enforce validation
%   Epsilon     - numeric scalar (default 0), regularization for frame power
%                 If >0: apply S = max(S, epsilon) to avoid division by zero
%                 If 0: error if any mode has zero frame power (strict mode)
%
% Output
%   X - [N×T] reconstructed vertex-domain signal
%
% Algorithm
%   1. Compute dual weights from analysis weights:
%      - Frame power: S(i) = sum_j |weights(i,j)|^2
%      - Dual: dual(i,j) = conj(weights(i,j)) / S(i)
%   
%   2. Reconstruct by synthesis with dual weights:
%      For each filter j=1:J:
%        Cj = mft * Yj            (transform subband to spectral)
%        Cj = dual(:,j) .* Cj     (apply dual weights)
%        X += imft * Cj           (accumulate reconstruction)
%
% Theory
%   The canonical dual filterbank provides near-perfect reconstruction when
%   the analysis filterbank forms a frame (sum of squared weights > 0 for
%   each mode). The reconstruction quality depends on frame bounds and
%   spectral coverage of the filterbank.
%
% Validation (Strict=true)
%   - Transform dimensions compatible (k, N)
%   - Weights size compatible (k, J)
%   - Subbands count matches J
%   - All subbands have consistent [N×T]
%   - Frame power S > 0 for all modes (unless Epsilon>0)
%
% Examples
%   % Design filterbank and analyze
%   M = bct.manifold.load();
%   E = M.eigenmodes(100);
%   F = bct.filter.design(E.eigenvalues.value, "Heat", "tau", [1 10 25 50]);
%   
%   mft_op = bct.manifold.operator.mft(M);
%   imft_op = bct.manifold.operator.imft(M);
%   signal = randn(M.nVertices, 1);
%   
%   % Analyze into subbands
%   subbands = bct.filter.analysis(mft_op, imft_op, signal, F);
%   
%   % Reconstruct using dual filterbank
%   reconstructed = bct.filter.inverse(mft_op, imft_op, subbands, F);
%   
%   % Check reconstruction error
%   error = norm(signal - reconstructed) / norm(signal);
%
%   % With regularization for incomplete coverage
%   reconstructed = bct.filter.inverse(mft_op, imft_op, subbands, F, ...
%       "Epsilon", 1e-6);
%
% Note
%   This is the recommended method for reconstruction. It differs from
%   adjoint synthesis (applying same weights) which does NOT guarantee
%   near-identity reconstruction.
%
% See also: bct.filter.synthesis, bct.filter.analysis, bct.filter.design

arguments
    mft {mustBeNumeric, mustBeReal}
    imft {mustBeNumeric, mustBeReal}
    Y  % [N×T×J] or {1×J} or [N×T]
    filterOrWeights  % struct or [k×J] numeric
    options.InputFormat (1,1) string {mustBeMember(options.InputFormat, ["auto", "stack", "cell"])} = "auto"
    options.Strict (1,1) logical = true
    options.Epsilon (1,1) {mustBeNumeric, mustBeNonnegative} = 0
end

%% Extract weights from filter struct or use directly
if isstruct(filterOrWeights)
    weights = filterOrWeights.weights;
else
    weights = filterOrWeights;
end

% Determine number of filters
[k_weights, J] = size(weights);

%% Detect input format
if strcmp(options.InputFormat, "auto")
    if iscell(Y)
        inputFormat = "cell";
    else
        inputFormat = "stack";
    end
else
    inputFormat = options.InputFormat;
end

%% Parse subbands and determine [N×T]
if strcmp(inputFormat, "cell")
    % Cell format: {1×J}
    if ~iscell(Y)
        error('bct:filter:inverse:InvalidInputFormat', ...
            'InputFormat="cell" but Y is not a cell array.');
    end
    
    J_input = numel(Y);
    
    if J_input ~= J
        error('bct:filter:inverse:SubbandCountMismatch', ...
            'Expected J=%d subbands but got J=%d.', J, J_input);
    end
    
    % Get [N×T] from first subband
    Y1 = Y{1};
    [N, T] = size(Y1);
    
    % Validate all subbands have same shape
    if options.Strict
        for j = 2:J
            [Nj, Tj] = size(Y{j});
            if Nj ~= N || Tj ~= T
                error('bct:filter:inverse:InconsistentSubbandShapes', ...
                    'Subband 1 is [%d×%d] but subband %d is [%d×%d].', ...
                    N, T, j, Nj, Tj);
            end
        end
    end
else
    % Stack format: [N×T×J] or [N×T] if J=1
    if J == 1
        % Single filter: Y is [N×T]
        if ndims(Y) > 2
            error('bct:filter:inverse:InvalidStackShape', ...
                'For J=1, Y should be [N×T] not 3D.');
        end
        [N, T] = size(Y);
        J_input = 1;
    else
        % Filterbank: Y is [N×T×J]
        if ndims(Y) ~= 3
            error('bct:filter:inverse:InvalidStackShape', ...
                'For J>1, Y should be [N×T×J] 3D array.');
        end
        [N, T, J_input] = size(Y);
        
        if J_input ~= J
            error('bct:filter:inverse:SubbandCountMismatch', ...
                'Expected J=%d subbands but Y has J=%d.', J, J_input);
        end
    end
end

%% Validation (Strict mode)
if options.Strict
    [k_mft, N_mft] = size(mft);
    [N_imft, k_imft] = size(imft);
    
    if ~ismatrix(mft) || isvector(mft)
        error('bct:filter:inverse:InvalidMFT', ...
            'Forward transform "mft" must be a 2D matrix [k×N].');
    end
    
    if ~ismatrix(imft) || isvector(imft)
        error('bct:filter:inverse:InvalidIMFT', ...
            'Inverse transform "imft" must be a 2D matrix [N×k].');
    end
    
    % Check N compatibility
    if N_mft ~= N || N_imft ~= N
        error('bct:filter:inverse:DimensionMismatch', ...
            ['N mismatch: mft expects N=%d, imft expects N=%d, subbands have N=%d.\n' ...
             'mft: [%d×%d], imft: [%d×%d]'], ...
            N_mft, N_imft, N, k_mft, N_mft, N_imft, k_imft);
    end
    
    % Check k compatibility
    if k_mft ~= k_imft || k_mft ~= k_weights
        error('bct:filter:inverse:DimensionMismatch', ...
            ['k mismatch: mft has k=%d, imft has k=%d, weights has k=%d.\n' ...
             'mft: [%d×%d], imft: [%d×%d], weights: [%d×%d]'], ...
            k_mft, k_imft, k_weights, k_mft, N_mft, N_imft, k_imft, k_weights, J);
    end
    
    % Validate weights are finite
    if any(~isfinite(weights(:)))
        error('bct:filter:inverse:NonFiniteWeights', ...
            'Filter weights contain non-finite values (NaN or Inf).');
    end
end

%% Compute dual weights
dual = dualWeights(weights, options.Epsilon, options.Strict);

%% Core computation: reconstruct using dual filterbank
X = zeros(N, T);

for j = 1:J
    % Get subband j
    if strcmp(inputFormat, "cell")
        Yj = Y{j};
    else
        if J == 1
            Yj = Y;
        else
            Yj = Y(:, :, j);
        end
    end
    
    % Transform subband to spectral domain
    Cj = mft * Yj;  % [k×T]
    
    % Apply dual filter weights
    Cj = dual(:, j) .* Cj;
    
    % Transform back and accumulate
    X = X + imft * Cj;
end

end
