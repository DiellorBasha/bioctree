function w = nearest(manifold, params)
%BCT.BRUSH.PATCH.NEAREST  Nearest-neighbor patch brush
%
%   w = bct.brush.patch.nearest(manifold, params)
%
%   Required params
%   ---------------
%   params.seed     : seed vertex index
%   params.distance : maximum distance from seed
%
%   Optional params
%   ---------------
%   params.metric   : "geometry" (default) | "fem" | custom metric
%
%   Note: Uses MATLAB's nearest() function which is optimized for
%         finding all nodes within a distance threshold.

    arguments
        manifold (1,1) bct.Manifold
        params struct
    end

    % --- Validate parameters ---
    if ~isfield(params,'seed') || ~isfield(params,'distance')
        error('bct:brush:patch:nearest', ...
              'params must contain seed and distance');
    end

    seed = params.seed;
    dist = params.distance;
    
    % --- Get metric ---
    if isfield(params, 'metric')
        metric = params.metric;
    else
        metric = "geometry";
    end

    % --- Use Graph distances to find vertices within distance threshold ---
    G = manifold.Graph();
    d = G.distances(metric);
    idx = find(d(:, seed) <= dist);

    % --- Binary selection field ---
    N = manifold.numVertices;
    w = zeros(N, 1);
    w(idx) = 1;

end
