function w = geodesic(manifold, params)
%BCT.BRUSH.TRAJECTORY.GEODESIC  Geodesic trajectory brush
%
%   w = bct.brush.trajectory.geodesic(manifold, params)
%
%   Required params
%   ---------------
%   params.source : source vertex index
%   params.target : target vertex index
%
%   Optional params
%   ---------------
%   params.metric : "geometry" (default) | "fem" | custom metric
%   params.width  : corridor width around path (0 = no corridor, default)
%
%   Note: When width > 0, creates a corridor of vertices within 'width' 
%         distance from any point on the geodesic path.

    arguments
        manifold (1,1) bct.Manifold
        params struct
    end

    % --- Validate parameters ---
    if ~isfield(params,'source') || ~isfield(params,'target')
        error('bct:brush:trajectory:geodesic', ...
              'params must contain source and target');
    end

    source = params.source;
    target = params.target;
    
    % --- Get metric ---
    if isfield(params, 'metric')
        metric = params.metric;
    else
        metric = "geometry";
    end
    
    % --- Get width ---
    if isfield(params, 'width')
        width = params.width;
    else
        width = 0;
    end

    % --- Compute shortest path ---
    [path, ~] = manifold.Graph.shortestPath(source, target, metric);

    % --- Apply width if specified ---
    if width > 0
        % Create corridor by finding all vertices within width distance
        % from any point on the path
        idx_all = [];
        graphObj = manifold.Graph();
        for i = 1:numel(path)
            d = graphObj.distances(metric);
            idx_i = find(d(:, path(i)) <= width);
            idx_all = [idx_all; idx_i]; %#ok<AGROW>
        end
        
        % Remove duplicates
        idx_all = unique(idx_all);
        
        % Binary selection field
        N = manifold.numVertices;
        w = zeros(N, 1);
        w(idx_all) = 1;
    else
        % No corridor - just the path
        N = manifold.numVertices;
        w = zeros(N, 1);
        w(path) = 1;
    end
end
