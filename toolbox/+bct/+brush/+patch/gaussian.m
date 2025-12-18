function w = gaussian(manifold, params)
%BCT.BRUSH.PATCH.GAUSSIAN  Gaussian-weighted patch brush
%
%   w = bct.brush.patch.gaussian(manifold, params)
%
%   Required params
%   ---------------
%   params.source : source vertex index (center of Gaussian)
%   params.sigma  : Gaussian width parameter (standard deviation)
%
%   Optional params
%   ---------------
%   params.metric : "geometry" (default) | "fem" | custom metric
%
%   Note: Returns Gaussian weights w = exp(-d^2 / (2*sigma^2))
%         where d is distance from source vertex.

    arguments
        manifold (1,1) bct.Manifold
        params struct
    end

    % --- Validate parameters ---
    if ~isfield(params,'source') || ~isfield(params,'sigma')
        error('bct:brush:patch:gaussian', ...
              'params must contain source and sigma');
    end

    source = params.source;
    sigma  = params.sigma;
    
    % --- Get metric ---
    if isfield(params, 'metric')
        metric = params.metric;
    else
        metric = "geometry";
    end

    % --- Compute distances from source ---
    G = manifold.Graph.matlabGraph(metric);
    d = distances(G, source);  % [N×1] distances from source to all vertices

    % --- Apply Gaussian kernel ---
    % w = exp(-d^2 / (2*sigma^2))
    w = exp(-d.^2 / (2*sigma^2));
    
    % --- Return as sparse column vector ---
    % Remove near-zero weights for sparsity (threshold at 1e-6)
    w(w < 1e-6) = 0;
    w = sparse(w);

end
