function X_TN = gaussian_growth(B, varargin)
%GAUSSIAN_GROWTH Generate time series with growing Gaussian width
%
%   X = bct.sim.gaussian_growth(B) generates a T×N time series where T=100
%       time points at fs=10 Hz, with Gaussian width growing from small to large
%
%   X = bct.sim.gaussian_growth(B, Name, Value) specifies options:
%
%   Parameters:
%       'T'          - Number of time points (default 100)
%       'fs'         - Sampling rate in Hz (default 10)
%       'center'     - Node index or [] for auto-select (default [])
%       'sigmaStart' - Initial sigma (default auto from graph)
%       'sigmaEnd'   - Final sigma (default auto from graph)
%       'distance'   - 'geodesic' (default) | 'euclidean'
%
%   Returns:
%       X_TN - T×N single precision time series
%
%   Example:
%       B = bct.io.import.mesh('lh.pial');
%       X = bct.sim.gaussian_growth(B, 'T', 200, 'fs', 20);
%
%   The function automatically selects a center node (nearest to coordinate
%   centroid if vertices exist, otherwise node 1) and computes sigma range
%   based on graph diameter.
%
%   See also: bct.sim.gaussian, bct.sim.multi_gaussian

    % Get dimensions from Manifold
    N = size(B.Manifold.V, 1);
    
    % Parse inputs
    p = inputParser;
    p.addParameter('T', 100, @(z)isscalar(z)&&z>0);
    p.addParameter('fs', 10, @(z)isscalar(z)&&z>0);
    p.addParameter('center', [], @(c)isempty(c)||(isnumeric(c)&&isscalar(c)));
    p.addParameter('sigmaStart', [], @(s)isempty(s)||isscalar(s));
    p.addParameter('sigmaEnd', [], @(s)isempty(s)||isscalar(s));
    p.addParameter('distance', 'geodesic', @(s)any(strcmpi(s,{'geodesic','euclidean'})));
    p.parse(varargin{:});
    
    T          = round(p.Results.T);
    fs         = p.Results.fs;
    center     = p.Results.center;
    sigmaStart = p.Results.sigmaStart;
    sigmaEnd   = p.Results.sigmaEnd;
    distMode   = lower(string(p.Results.distance));
    
    % Auto-select center if not provided
    if isempty(center)
        coords = B.Manifold.V;
        if ~isempty(coords)
            ctr = mean(double(coords),1);
            center = nearestNodeIdx(ctr, coords);
        else
            center = 1;
        end
    end
    
    % Auto-compute sigma range if not provided
    if isempty(sigmaStart) || isempty(sigmaEnd)
        % Compute geodesic distances for heuristics
        A = B.Manifold.adjacency();
        if ~isequal(A, A')
            A = max(A, A');
        end
        Gm = graph(A, 'OmitSelfLoops');
        d_all = distances(Gm, center, 'Method','positive');
        d_all = full(d_all(:));
        d_all(~isfinite(d_all)) = 0;
        
        graph_diam = max(d_all);
        
        if isempty(sigmaStart)
            sigmaStart = max(1e-3, prctile(nonzeros(d_all),5));
            if ~isfinite(sigmaStart)||sigmaStart<=0
                sigmaStart=1e-2;
            end
        end
        
        if isempty(sigmaEnd)
            sigmaEnd = max(sigmaStart*5, max(2, graph_diam/3));
        end
    end
    
    % Generate time series with linearly growing sigma
    sigmas = linspace(sigmaStart, sigmaEnd, T);
    X_TN   = zeros(T, N, 'single');
    
    for t=1:T
        x = bct.sim.gaussian(B, 'center', center, 'sigma', sigmas(t), 'distance', distMode);
        X_TN(t,:) = x;
    end
end

%% Helper function
function idx = nearestNodeIdx(C, coords)
    % Find nearest node index for coordinate C
    if isvector(C), C = C(:)'; end
    dd = vecnorm(double(coords) - double(C), 2, 2);
    [~, idx] = min(dd);
end
