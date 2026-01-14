function Xhat = synthesis(mft, imft, Y, filterOrWeights, options)
%BCT.FILTER.SYNTHESIS  Recombine subband signals into reconstructed signal
%
%   Xhat = bct.filter.synthesis(mft, imft, Y, F)
%   Xhat = bct.filter.synthesis(mft, imft, Y, weights)
%
% Purpose
%   Recombines subband signals produced by bct.filter.analysis into a
%   reconstructed signal using the synthesis operator for the filterbank.
%   This is NOT guaranteed to be perfect reconstruction (use dual filters
%   for that - future bct.filter.inverse).
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
%                 "stack": Y is [N×T×J] array
%                 "cell":  Y is {1×J} cell
%   Strict      - logical (default true), enforce validation
%
% Output
%   Xhat - [N×T] reconstructed vertex-domain signal
%
% Algorithm
%   For each filter j=1:J:
%     1. Cj = mft * Yj            (transform subband to spectral domain)
%     2. Cj = weights(:,j) .* Cj  (apply filter j weights)
%     3. Xhat += imft * Cj        (accumulate reconstruction)
%
% Validation (Strict=true)
%   - Transform dimensions compatible
%   - Number of subbands equals J
%   - All subbands have same [N×T] shape
%   - All weights finite
%
% Examples
%   % Design filterbank and apply
%   M = bct.manifold.load();
%   E = M.eigenmodes(100);
%   F = bct.filter.design(E.values, "Heat", "tau", [1 10 25 50]);
%   
%   mft_op = bct.manifold.operator.mft(M);
%   imft_op = bct.manifold.operator.imft(M);
%   signal = randn(M.nVertices, 1);
%   
%   % Analysis (decompose)
%   subbands = bct.filter.analysis(mft_op, imft_op, signal, F);  % [N×T×4]
%   
%   % Synthesis (recombine)
%   reconstructed = bct.filter.synthesis(mft_op, imft_op, subbands, F);  % [N×T]
%
%   % Cell format
%   subbands_cell = bct.filter.analysis(mft_op, imft_op, signal, F, ...
%       "OutputFormat", "cell");
%   reconstructed = bct.filter.synthesis(mft_op, imft_op, subbands_cell, F);
%
% Note
%   This synthesis does NOT perform perfect reconstruction. For that,
%   you need dual filters (future bct.filter.inverse).
%
% See also: bct.filter.analysis, bct.filter.design, bct.manifold.operator.imft

arguments
    mft {mustBeNumeric, mustBeReal}
    imft {mustBeNumeric, mustBeReal}
    Y  % [N×T×J] or {1×J} or [N×T]
    filterOrWeights  % struct or [k×J] numeric
    options.InputFormat (1,1) string {mustBeMember(options.InputFormat, ["auto", "stack", "cell"])} = "auto"
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
        error('bct:filter:synthesis:InvalidInputFormat', ...
            'InputFormat="cell" but Y is not a cell array.');
    end
    
    J_input = numel(Y);
    
    if J_input ~= J
        error('bct:filter:synthesis:SubbandCountMismatch', ...
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
                error('bct:filter:synthesis:InconsistentSubbandShapes', ...
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
            error('bct:filter:synthesis:InvalidStackShape', ...
                'For J=1, Y should be [N×T] not 3D.');
        end
        [N, T] = size(Y);
        J_input = 1;
    else
        % Filterbank: Y is [N×T×J]
        if ndims(Y) ~= 3
            error('bct:filter:synthesis:InvalidStackShape', ...
                'For J>1, Y should be [N×T×J] 3D array.');
        end
        [N, T, J_input] = size(Y);
        
        if J_input ~= J
            error('bct:filter:synthesis:SubbandCountMismatch', ...
                'Expected J=%d subbands but Y has J=%d.', J, J_input);
        end
    end
end

%% Validation (Strict mode)
if options.Strict
    [k_mft, N_mft] = size(mft);
    [N_imft, k_imft] = size(imft);
    
    if ~ismatrix(mft) || isvector(mft)
        error('bct:filter:synthesis:InvalidMFT', ...
            'Forward transform "mft" must be a 2D matrix [k×N].');
    end
    
    if ~ismatrix(imft) || isvector(imft)
        error('bct:filter:synthesis:InvalidIMFT', ...
            'Inverse transform "imft" must be a 2D matrix [N×k].');
    end
    
    % Check N compatibility
    if N_mft ~= N || N_imft ~= N
        error('bct:filter:synthesis:DimensionMismatch', ...
            ['N mismatch: mft expects N=%d, imft expects N=%d, subbands have N=%d.\n' ...
             'mft: [%d×%d], imft: [%d×%d]'], ...
            N_mft, N_imft, N, k_mft, N_mft, N_imft, k_imft);
    end
    
    % Check k compatibility
    if k_mft ~= k_imft || k_mft ~= k_weights
        error('bct:filter:synthesis:DimensionMismatch', ...
            ['k mismatch: mft has k=%d, imft has k=%d, weights has k=%d.\n' ...
             'mft: [%d×%d], imft: [%d×%d], weights: [%d×%d]'], ...
            k_mft, k_imft, k_weights, k_mft, N_mft, N_imft, k_imft, k_weights, J);
    end
    
    % Validate weights are finite
    if any(~isfinite(weights(:)))
        error('bct:filter:synthesis:NonFiniteWeights', ...
            'Filter weights contain non-finite values (NaN or Inf).');
    end
end

%% Core computation: recombine subbands
Xhat = zeros(N, T);

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
    
    % Apply filter weights
    Cj = weights(:, j) .* Cj;
    
    % Transform back and accumulate
    Xhat = Xhat + imft * Cj;
end

end
