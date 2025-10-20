function tv = graphTotalVariation(G, X, p)
% GRAPHTOTALVARIATION Compute total variation of graph signals
%
% tv = graphTotalVariation(G, X) computes the L1 total variation (TV) of 
% signals X on graph G. TV measures spatial roughness/smoothness of signals.
%
% tv = graphTotalVariation(G, X, p) computes the Lp total variation with
% parameter p (default: p=1 for L1 norm).
%
% Inputs:
%   G - Graph structure with adjacency or Laplacian
%   X - Signal matrix (N x T) where N=vertices, T=time points  
%   p - Norm parameter (default: 1 for L1 TV)
%
% Outputs:
%   tv - Total variation per vertex (N x T)
%
% Mathematical Definition:
%   TV_p(x)[i] = (∑_{j∈N(i)} w_{ij} |x[i] - x[j]|^p)^(1/p)
%
%   Where N(i) are neighbors of vertex i, w_{ij} are edge weights.
%   For p=1: TV(x)[i] = ∑_{j∈N(i)} w_{ij} |x[i] - x[j]|
%   For p=2: TV(x)[i] = (∑_{j∈N(i)} w_{ij} (x[i] - x[j])²)^(1/2)
%
% Example:
%   % Compute L1 total variation on cortical graph
%   G = fromCortex(vertices, faces);
%   x = randn(G.N, 100);  % Random signals
%   tv1 = graphTotalVariation(G, x, 1);  % L1 TV
%   tv2 = graphTotalVariation(G, x, 2);  % L2 TV
%   
%   % Smooth signals have lower TV
%   x_smooth = gsp_filter(G, x, @(x) exp(-x));
%   tv_smooth = graphTotalVariation(G, x_smooth);
%
% References:
%   Shuman et al. "The emerging field of signal processing on graphs" (2013)
%   Ortega et al. "Graph Signal Processing: Overview, Challenges, Applications" (2018)
%
% See also: graphGradient, graphDivergence

% Input validation
if nargin < 3
    p = 1;  % Default to L1 total variation
end

if ~isfield(G, 'W') || isempty(G.W)
    error('Graph must have adjacency matrix G.W');
end

if ~isfield(G, 'N') || G.N ~= size(X, 1)
    error('Signal dimension must match graph size');
end

% Get graph properties
N = G.N;
W = G.W;

% Handle different input dimensions
if isvector(X)
    X = X(:);  % Make column vector
    T = 1;
else
    [N_check, T] = size(X);
    if N_check ~= N
        error('Signal matrix first dimension (%d) must match graph size (%d)', N_check, N);
    end
end

% Initialize output
tv = zeros(N, T);

% Compute total variation for each vertex and time point
for i = 1:N
    % Find neighbors of vertex i
    neighbors = find(W(i, :));
    
    if isempty(neighbors)
        % Isolated vertex has zero TV
        tv(i, :) = 0;
        continue;
    end
    
    % Get edge weights to neighbors
    weights = full(W(i, neighbors));
    
    % Compute differences to all neighbors
    for t = 1:T
        x_i = X(i, t);
        x_neighbors = X(neighbors, t);
        
        % Compute weighted differences
        diffs = abs(x_i - x_neighbors);
        
        % Ensure compatible dimensions for multiplication
        weights = weights(:);  % Column vector
        diffs = diffs(:);      % Column vector
        
        if p == 1
            % L1 total variation (standard)
            tv(i, t) = sum(weights .* diffs);
        elseif p == 2
            % L2 total variation
            tv(i, t) = sqrt(sum(weights .* (diffs.^2)));
        else
            % General Lp norm
            tv(i, t) = (sum(weights .* (diffs.^p)))^(1/p);
        end
    end
end

% Handle edge case: if p approaches infinity, use max norm
if isinf(p)
    for i = 1:N
        neighbors = find(W(i, :));
        if ~isempty(neighbors)
            weights = full(W(i, neighbors));
            for t = 1:T
                x_i = X(i, t);
                x_neighbors = X(neighbors, t);
                diffs = abs(x_i - x_neighbors);
                tv(i, t) = max(weights .* diffs);
            end
        end
    end
end

end