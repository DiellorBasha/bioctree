function w = gaussian(manifold, params)
%BCT.BRUSH.TRAJECTORY.GAUSSIAN  Gaussian-weighted trajectory brush
%
%   w = bct.brush.trajectory.gaussian(manifold, params)
%
%   Required params
%   ---------------
%   params.source : source vertex index
%   params.target : target vertex index
%   params.sigma  : Gaussian width parameter (standard deviation)
%
%   Optional params
%   ---------------
%   params.metric : "geometry" (default) | "fem" | custom metric
%
%   Note: Creates Gaussian weights along geodesic path.
%         Weight = exp(-d^2 / (2*sigma^2)) where d is distance
%         to nearest point on the path.

    arguments
        manifold (1,1) bct.Manifold
        params struct
    end

    % --- Validate parameters ---
    if ~isfield(params,'source') || ~isfield(params,'target') || ~isfield(params,'sigma')
        error('bct:brush:trajectory:gaussian', ...
              'params must contain source, target, and sigma');
    end

    source = params.source;
    target = params.target;
    sigma  = params.sigma;
    
    % --- Get metric ---
    if isfield(params, 'metric')
        metric = params.metric;
    else
        metric = "geometry";
    end

    % --- Compute geodesic path ---
    [path, ~] = manifold.Graph.shortestPath(source, target, metric);

    % --- Compute Gaussian weights around path ---
    % Use nearest() with cutoff at 3*sigma to find vertices near path
    % (beyond 3*sigma, Gaussian weight < 1% anyway)
    
    cutoff = 3 * sigma;
    N = manifold.N;
    w = zeros(N, 1);
    
    % For each vertex on the path, find nearby vertices and weight them
    for i = 1:numel(path)
        % Get vertices within cutoff distance from this path vertex
        idx = manifold.Graph.nearest(path(i), cutoff, metric);
        
        % Compute shortest path distances to these vertices
        [~, dists] = manifold.Graph.shortestPath(path(i), idx, metric);
        
        % Apply Gaussian: w = exp(-d^2 / (2*sigma^2))
        % Take maximum weight if vertex is near multiple path points
        w_i = exp(-dists.^2 / (2*sigma^2));
        w(idx) = max(w(idx), w_i);
    end

    % --- Return as sparse column vector ---
    w(w < 1e-6) = 0;
    w = sparse(w);

end
