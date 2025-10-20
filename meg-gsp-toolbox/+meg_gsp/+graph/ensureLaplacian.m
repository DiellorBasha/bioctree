function G = ensureLaplacian(G, varargin)
% ENSURELAPLACIAN Compute or update Laplacian matrix for GSPBOX graph
%
% G = ensureLaplacian(G) computes the normalized Laplacian L = D^(-1/2) * (D - W) * D^(-1/2)
% where D is the degree matrix and W is the weight matrix.
%
% G = ensureLaplacian(G, opts) specifies options:
%   'NormalizedLap' - true (default) for normalized, false for combinatorial
%   'LaplacianType' - 'normalized' (default), 'combinatorial', or 'random_walk'  
%   'Regularize'    - true/false to add small regularization (default: true)
%   'RegParam'      - regularization parameter (default: 1e-12)
%
% Input:
%   G - Graph structure with at least G.W (weight matrix)
%
% Output:
%   G - Graph structure with added/updated fields:
%     .L      - Laplacian matrix
%     .d      - Degree vector  
%     .lmax   - Maximum eigenvalue (Laplacian spectral radius)
%     .lap_type - Type of Laplacian computed
%
% Example:
%   G = meg_gsp.graph.ensureLaplacian(G);
%   G = meg_gsp.graph.ensureLaplacian(G, struct('NormalizedLap', false));
%
% References:
%   Laplacian definitions follow standard graph theory conventions:
%   - Combinatorial: L = D - W
%   - Normalized: L = D^(-1/2) * (D - W) * D^(-1/2) = I - D^(-1/2) * W * D^(-1/2)
%   - Random walk: L_rw = D^(-1) * (D - W) = I - D^(-1) * W
%
% See also: fromCortex, gsp_compute_fourier_basis

% Input validation
if ~isstruct(G) || ~isfield(G, 'W')
    error('Input must be graph structure with weight matrix G.W');
end

% Parse options
if nargin >= 2 && isstruct(varargin{1})
    opts = varargin{1};
else
    opts = struct();
    for i = 1:2:length(varargin)-1
        opts.(varargin{i}) = varargin{i+1};
    end
end

% Set defaults
if ~isfield(opts, 'NormalizedLap'), opts.NormalizedLap = true; end
if ~isfield(opts, 'LaplacianType')
    if opts.NormalizedLap
        opts.LaplacianType = 'normalized';
    else
        opts.LaplacianType = 'combinatorial';
    end
end
if ~isfield(opts, 'Regularize'), opts.Regularize = true; end
if ~isfield(opts, 'RegParam'), opts.RegParam = 1e-12; end

% Extract weight matrix
W = G.W;
N = size(W, 1);

% Ensure W is sparse and symmetric
if ~issparse(W)
    W = sparse(W);
end
W = (W + W') / 2;  % Enforce symmetry

% Compute degree vector
d = full(sum(W, 2));

% Handle isolated vertices (zero degree)
isolated = (d == 0);
if any(isolated)
    warning('Graph has %d isolated vertices. Adding self-loops.', sum(isolated));
    W(isolated, isolated) = opts.RegParam;
    d(isolated) = opts.RegParam;
end

% Add regularization if requested
if opts.Regularize && opts.RegParam > 0
    W = W + opts.RegParam * speye(N);
    d = d + opts.RegParam;
end

% Compute Laplacian based on type
switch lower(opts.LaplacianType)
    case 'combinatorial'
        % L = D - W
        D = spdiags(d, 0, N, N);
        L = D - W;
        lap_type = 'combinatorial';
        
    case 'normalized'
        % L = D^(-1/2) * (D - W) * D^(-1/2) = I - D^(-1/2) * W * D^(-1/2)
        d_sqrt_inv = 1 ./ sqrt(d);
        d_sqrt_inv(~isfinite(d_sqrt_inv)) = 0;
        
        D_sqrt_inv = spdiags(d_sqrt_inv, 0, N, N);
        L = speye(N) - D_sqrt_inv * W * D_sqrt_inv;
        lap_type = 'normalized';
        
    case 'random_walk'
        % L_rw = I - D^(-1) * W
        d_inv = 1 ./ d;
        d_inv(~isfinite(d_inv)) = 0;
        
        D_inv = spdiags(d_inv, 0, N, N);
        L = speye(N) - D_inv * W;
        lap_type = 'random_walk';
        
    otherwise
        error('Unknown Laplacian type: %s', opts.LaplacianType);
end

% Store results in graph structure
G.L = L;
G.d = d;
G.lap_type = lap_type;

% Compute spectral radius (maximum eigenvalue)
try
    G.lmax = full(max(real(eigs(L, 1, 'largestreal', ...
                              'SubspaceDimension', min(20, N-1)))));
catch
    % Fallback for small matrices or if eigs fails
    warning('Could not compute spectral radius with eigs. Using full eigendecomposition.');
    eigvals = real(eig(full(L)));
    G.lmax = max(eigvals);
end

% Theoretical bounds check
switch lap_type
    case 'normalized'
        if G.lmax > 2.001  % Allow small numerical error
            warning('Normalized Laplacian spectral radius (%.4f) exceeds theoretical maximum of 2', G.lmax);
        end
        G.lmax = min(G.lmax, 2);  % Clamp to theoretical maximum
        
    case 'random_walk'  
        if G.lmax > 1.001
            warning('Random walk Laplacian spectral radius (%.4f) exceeds theoretical maximum of 1', G.lmax);
        end
        G.lmax = min(G.lmax, 1);
end

end