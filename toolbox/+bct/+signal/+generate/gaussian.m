```matlab
function x = gaussian(B, varargin)
%GAUSSIAN Generate static spatial Gaussian signal on graph manifold
%
%   x = bct.sim.gaussian(B) generates a Gaussian signal centered at node 1
%       with default width sigma=8
%
%   x = bct.sim.gaussian(B, Name, Value) specifies options:
%
%   Parameters:
%       'center'      - Node index (1-based) or coordinate row vec
%       'center_type' - 'node' (default) | 'coord'
%       'sigma'       - Width parameter (>0), default 8
%       'amplitude'   - Scalar amplitude; [] -> normalize max=1 (default)
%       'combine'     - 'sum' (default) | 'max' (if multiple centers)
%       'distance'    - 'auto' | 'euclidean' | 'geodesic'
%                       auto = euclidean if coords exist, else geodesic
%
%   Returns:
%       x - N×1 single precision signal on manifold vertices
%
%   Example:
%       B = bct.io.import.mesh('lh.pial');
%       x = bct.sim.gaussian(B, 'center', 1000, 'sigma', 10);
%
%   See also: bct.sim.gaussian_growth, bct.sim.multi_gaussian

    % Get dimensions from Manifold
    N = size(B.Manifold.V, 1);
    
    % Parse inputs
    p = inputParser;
    p.addParameter('center', 1, @(c)isnumeric(c) && ~isempty(c));
    p.addParameter('center_type','node',@(s)ischar(s)||isstring(s));
    p.addParameter('sigma', 8, @(s)isnumeric(s) && all(s(:)>0));
    p.addParameter('amplitude', [], @(a) isempty(a) || isscalar(a));
    p.addParameter('combine', 'sum', @(s) any(strcmpi(s,{'sum','max'})));
    p.addParameter('distance','auto', @(s) any(strcmpi(s,{'auto','euclidean','geodesic'})));
    p.parse(varargin{:});
    
    center      = p.Results.center;
    center_type = lower(string(p.Results.center_type));
    sigma       = p.Results.sigma;
    amp         = p.Results.amplitude;
    combine     = lower(string(p.Results.combine));
    distMode    = lower(string(p.Results.distance));
    
    % Resolve centers to node indices
    if center_type=="node"
        c_idx = round(center(:));
        if any(c_idx<1 | c_idx>N)
            error('bct:sim:CenterOutOfRange','Center node index out of range 1..N=%d.', N);
        end
    elseif center_type=="coord"
        coords = B.Manifold.V;
        if isempty(coords)
            error('bct:sim:NoCoords','center_type="coord" requires vertex coordinates in Manifold.');
        end
        C = center; 
        if isvector(C), C = C(:)'; end
        if size(C,2)~=size(coords,2)
            error('bct:sim:CoordDimMismatch','Coord dims mismatch.');
        end
        c_idx = nearestNodeIdx(C, coords);
    else
        error('bct:sim:BadCenterType','Unknown center_type: %s', center_type);
    end
    
    % Sigma broadcasting
    if isscalar(sigma)
        sigma = repmat(sigma, numel(c_idx), 1);
    end
    if numel(sigma) ~= numel(c_idx)
        error('bct:sim:SigmaCountMismatch','Length of sigma must match centers.');
    end
    
    % Distance mode resolution
    if distMode=="auto"
        if ~isempty(B.Manifold.V)
            distMode="euclidean";
        else
            distMode="geodesic";
        end
    end
    
    % Accumulate Gaussians
    acc = zeros(N, numel(c_idx), 'double');
    for k=1:numel(c_idx)
        d = nodeDistances(B, c_idx(k), distMode);
        acc(:,k) = exp(-(d.^2)/(2*sigma(k)^2));
    end
    
    switch combine
        case 'sum', x = sum(acc,2);
        case 'max', x = max(acc,[],2);
    end
    
    % Apply amplitude
    if isempty(amp)
        m=max(x); 
        if m>0, x=x/m; end
    else
        x = amp.*x;
    end
    
    x = single(x);
end

%% Helper functions
function d = nodeDistances(B, centerIdx, mode)
    % Compute distances from centerIdx to all nodes
    switch lower(string(mode))
        case "euclidean"
            coords = B.Manifold.V;
            if isempty(coords)
                error('bct:sim:NoCoords','Euclidean mode requires vertex coords in Manifold.');
            end
            d = vecnorm(double(coords) - double(coords(centerIdx,:)), 2, 2);
            
        case "geodesic"
            % Use adjacency matrix from Manifold
            A = B.Manifold.adjacency();
            if ~isequal(A, A')
                A = max(A, A');
            end
            Gm = graph(A, 'OmitSelfLoops');
            d = distances(Gm, centerIdx, 'Method','positive');
            d = full(d(:));
            
        otherwise
            error('bct:sim:BadDistMode','Unknown distance mode: %s', mode);
    end
    d = double(d(:));
end

function idx = nearestNodeIdx(C, coords)
    % Find nearest node indices for coordinate matrix C
    if isvector(C), C = C(:)'; end
    M = size(C,1); 
    idx = zeros(M,1);
    for m=1:M
        dd = vecnorm(double(coords) - double(C(m,:)), 2, 2);
        [~, idx(m)] = min(dd);
    end
end

```
