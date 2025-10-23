classdef sim < handle
% bct.sim.sim — B-bound simulator for graph signals (Gaussian static + default growth series)
%
% Integration notes (matches your bct API):
%   - Graph I/O via:   B.write_graph(G_struct)
%   - Axes/signals via: B.write_raw_layers(XLTN, fs), B.append_raw_layer(XTN, layer_id0based)
%   - Axis queries via: B.read_axis('node_id'), B.has('/path'), B.read_coords(), B.read_graph_gsp()
%
% Defaults requested:
%   • If no graph in file: build default G = gsp_bunny(), then G = gsp_estimate_lmax(G),
%     and write it to the file (coords + edges) via B.write_graph.
%   • If no input props are given for the signal: call gsp_jtv_graph(G, T=100, fs=10, params),
%     then generate a growth signal X (T×N) with sigma(t) increasing from very small at t=1
%     to large at t=100. Sampling rate fs=10 Hz.
%
% Key methods:
%   S = bct.sim.sim(B);
%   x = S.gaussian(...);                 % N×1 static spatial Gaussian
%   X = S.gaussian_growth_default();     % T×N, T=100, fs=10, increasing width
%   lid = S.write_layer(X);              % write to /signals/raw_stack (and init axes if needed)
%
% Requires GSPBox on the MATLAB path for gsp_bunny / gsp_estimate_lmax / gsp_jtv_graph.

    properties (SetAccess=private)
        B               % bct.bct handle
        N double        % node count
        fs_default double = 10
        T_default  double = 100
        % Cached from file (if present / after ensure_graph):
        Gsp % GSPBox graph struct with fields W, coords, (maybe) lmax
    end

    methods
        function obj = sim(B)
            % B is a bct.bct instance
            obj.B = B;
            
            % Ensure a graph exists in the file (creates bunny if needed)
            obj.ensure_graph_in_file();
            
            % Get node count first - either from axes or infer from graph structure
            if obj.B.has("/axes/node_id")
                node_id = obj.B.read_axis('node_id'); % int32 0..N-1
                obj.N = numel(node_id);
            else
                % Infer N from graph edges
                obj.N = obj.infer_node_count_from_graph();
            end
            
            % Cache GSP graph from file (now that obj.N is set)
            obj.Gsp = obj.load_gsp_from_file();
        end

        % ---------- API: static spatial Gaussian: single(N,1) ----------
        function x = gaussian(obj, varargin)
            % Name-Value:
            %   'center'      : node index (1-based) or coordinate row vec
            %   'center_type' : 'node' (default) | 'coord'
            %   'sigma'       : width (>0)
            %   'amplitude'   : scalar amplitude; [] -> normalize max=1
            %   'combine'     : 'sum' (default) | 'max' (if multiple centers)
            %   'distance'    : 'auto' (euclidean if coords exist, else geodesic)
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
                if any(c_idx<1 | c_idx>obj.N)
                    error('bct:sim:CenterOutOfRange','Center node index out of range 1..N.');
                end
            elseif center_type=="coord"
                coords = obj.try_read_coords();
                if isempty(coords), error('bct:sim:NoCoords','center_type="coord" requires coords in file.'); end
                C = center; if isvector(C), C = C(:)'; end
                if size(C,2)~=size(coords,2), error('bct:sim:CoordDimMismatch','Coord dims mismatch.'); end
                c_idx = obj.nearestNodeIdx(C, coords);
            else
                error('bct:sim:BadCenterType','Unknown center_type: %s', center_type);
            end

            % Sigma broadcasting
            if isscalar(sigma), sigma = repmat(sigma, numel(c_idx), 1); end
            if numel(sigma) ~= numel(c_idx)
                error('bct:sim:SigmaCountMismatch','Length of sigma must match centers.');
            end

            % Distance mode
            if distMode=="auto"
                if ~isempty(obj.try_read_coords()), distMode="euclidean";
                else,                              distMode="geodesic";
                end
            end

            % Accumulate Gaussians
            acc = zeros(obj.N, numel(c_idx), 'double');
            for k=1:numel(c_idx)
                d = obj.nodeDistances(c_idx(k), distMode);
                acc(:,k) = exp(-(d.^2)/(2*sigma(k)^2));
            end
            switch combine
                case 'sum', x = sum(acc,2);
                case 'max', x = max(acc,[],2);
            end

            if isempty(amp)
                m=max(x); if m>0, x=x/m; end
            else
                x = amp.*x;
            end
            x = single(x);
        end

        % ---------- API: default growth time series X(T×N), T=100, fs=10 ----------
        function X_TN = gaussian_growth_default(obj, varargin)
            % Name-Value (all optional):
            %   'T' : integer (default 100)
            %   'fs': Hz (default 10)
            p = inputParser;
            p.addParameter('T', obj.T_default, @(z)isscalar(z)&&z>0);
            p.addParameter('fs', obj.fs_default, @(z)isscalar(z)&&z>0);
            p.parse(varargin{:});
            T  = round(p.Results.T);
            fs = p.Results.fs;

            % Best-effort: build JTV graph (not strictly needed)
            try, params = struct(); gsp_jtv_graph(obj.Gsp, T, fs, params); %#ok<NASGU>
            catch, % continue silently
            end

            % Choose a center: nearest to coordinate centroid if coords exist, else node 1
            coords = obj.try_read_coords();
            if ~isempty(coords)
                ctr = mean(double(coords),1);
                c = obj.nearestNodeIdx(ctr, coords);
            else
                c = 1;
            end

            % Heuristics for sigma range (geodesic units)
            d_all = obj.nodeDistances(c, 'geodesic');
            d_all(~isfinite(d_all)) = 0;
            graph_diam = max(d_all);
            sigmaStart = max(1e-3, prctile(nonzeros(d_all),5)); if ~isfinite(sigmaStart)||sigmaStart<=0, sigmaStart=1e-2; end
            sigmaEnd   = max(sigmaStart*5, max(2, graph_diam/3));

            sigmas = linspace(sigmaStart, sigmaEnd, T);
            X_TN   = zeros(T, obj.N, 'single');
            for t=1:T
                x = obj.gaussian('center', c, 'sigma', sigmas(t), 'distance','geodesic');
                X_TN(t,:) = x;
            end
        end

        % ---------- API: write layer (vector N×1 or matrix T×N/N×T) ----------
        function layer_id1 = write_layer(obj, x, fs_opt, layer_id0based)
            % Writes x into /signals/raw_stack (appending or initializing).
            % x may be N×1 (stored as T=1) or T×N (preferred). If N×T is passed, we transpose.
            % If this is the first write, we call B.write_raw_layers with fs (default 10 Hz).
            if nargin < 3 || isempty(fs_opt), fs_opt = obj.fs_default; end
            if nargin < 4, layer_id0based = []; end

            x = single(x);
            if isvector(x)
                if numel(x) ~= obj.N
                    error('bct:sim:VectorSizeMismatch','Vector length must be N=%d.', obj.N);
                end
                XTN = reshape(x, 1, obj.N);  % T=1
            else
                [r,c] = size(x);
                if c == obj.N
                    XTN = x;              % T×N
                elseif r == obj.N
                    warning('bct:sim:Transposing','Detected N×T; transposing to T×N for BCT.');
                    XTN = x.';           % make T×N
                else
                    error('bct:sim:MatrixSizeMismatch','x must be T×N (or N×T) with N=%d.', obj.N);
                end
            end

            % Decide whether to initialize or append
            has_stack = obj.pathExists("/signals/raw_stack");
            if ~has_stack
                % Initialize stack with L=1 using write_raw_layers (creates axes & /signals/raw)
                XLTN = reshape(XTN, [1, size(XTN,1), size(XTN,2)]); % L=1
                obj.B.write_raw_layers(XLTN, fs_opt); % sets /axes/time_s and fs_hz
                layer_id1 = 1; % first (1-based)
                return;
            end

            % Append to existing stack: need layer_id0based
            if isempty(layer_id0based)
                % Read layer_id axis using BCT method
                if obj.B.has("/axes/layer_id")
                    lid = obj.B.read_axis('layer_id'); % int32 0..L-1
                    layer_id0based = double(numel(lid)); % append at end
                else
                    layer_id0based = 0; % first layer
                end
            end
            obj.B.append_raw_layer(XTN, layer_id0based);
            layer_id1 = layer_id0based + 1;
        end
    end

    % ---------- internals ----------
    methods (Access=private)
        function ensure_graph_in_file(obj)
            % If no graph in file, create default graph and write it via B.write_graph
            if obj.pathExists("/graph/edges/coo_i")
                return;
            end
            
            % Try GSPBox bunny first, fallback to simple default
            if exist('gsp_bunny','file') == 2
                G = gsp_bunny();
                try, G = gsp_estimate_lmax(G); catch, end
                
                % Prepare G struct for B.write_graph (MATLAB 1-based E list)
                [ii,jj,ww] = find(G.W); sel = ii<jj; ii=ii(sel); jj=jj(sel); ww=ww(sel);
                Gs = struct( ...
                    'coords', single(G.coords), ...
                    'E', [double(ii) double(jj) single(ww)], ...
                    'lap_type', 'combinatorial', ...
                    'lmax', single(isfield(G,'lmax') * G.lmax) ...
                );
            else
                % Fallback: create simple 10-node circle graph
                warning('bct:sim:GSPBoxMissing','GSPBox not found. Creating simple circle graph.');
                nNodes = 10; 
                % Simple circle: node i connected to nodes i-1 and i+1 (with wraparound)
                ii = [1:nNodes, 1:nNodes]; 
                jj = [2:nNodes, 1, [2:nNodes, 1]];  % Each node connects to next and prev
                ww = ones(1, 2*nNodes);
                % Remove duplicate edges (keep only i<j)
                edges = [ii(:), jj(:), ww(:)];
                edges = edges(edges(:,1) < edges(:,2), :);
                
                % Create 3D coordinates for circle
                theta = 2*pi*(0:nNodes-1)/nNodes;
                coords = single([cos(theta)', sin(theta)', zeros(nNodes,1)]);
                
                Gs = struct( ...
                    'coords', coords, ...
                    'E', edges, ...
                    'lap_type', 'combinatorial', ...
                    'lmax', single(4) ... % approximate for circle graph
                );
            end
            obj.B.write_graph(Gs);
        end

        function G = load_gsp_from_file(obj)
            % Use BCT's read_graph_gsp method
            G = obj.B.read_graph_gsp();
            if isempty(G)
                % Fallback if no graph exists (shouldn't happen after ensure_graph_in_file)
                G = struct('W', sparse(obj.N,obj.N), 'N', obj.N);
                coords = obj.try_read_coords();
                if ~isempty(coords), G.coords = double(coords); end
            end
        end

        function coords = try_read_coords(obj)
            coords = obj.B.read_coords(); % Use BCT method
        end

        function d = nodeDistances(obj, centerIdx, mode)
            % Geodesic via MATLAB graph distances; Euclidean via coords
            switch lower(string(mode))
                case "euclidean"
                    C = obj.try_read_coords();
                    if isempty(C), error('bct:sim:NoCoords','Euclidean mode requires coords in file.'); end
                    d = vecnorm(double(C) - double(C(centerIdx,:)), 2, 2);

                case "geodesic"
                    W = obj.Gsp.W; if ~isequal(W,W.'), W = max(W,W.'); end
                    Gm = graph(W, 'OmitSelfLoops');
                    d = distances(Gm, centerIdx, 'Method','positive'); d = full(d(:));

                otherwise
                    error('bct:sim:BadDistMode','Unknown distance mode: %s', mode);
            end
            d = double(d(:));
        end

        function idx = nearestNodeIdx(~, C, coords)
            if isvector(C), C = C(:)'; end
            M = size(C,1); idx = zeros(M,1);
            for m=1:M
                dd = vecnorm(double(coords) - double(C(m,:)), 2, 2);
                [~, idx(m)] = min(dd);
            end
        end

        function nNodes = infer_node_count_from_graph(obj)
            % Infer node count from graph edges in file using BCT methods
            if obj.B.has("/graph/edges/coo_i")
                i0 = h5read(obj.B.fn, '/graph/edges/coo_i'); % int32 0-based
                j0 = h5read(obj.B.fn, '/graph/edges/coo_j');
                nNodes = double(max([max(i0), max(j0)])) + 1; % +1 for 0-based indexing
            else
                % No graph exists yet - this shouldn't happen after ensure_graph_in_file
                nNodes = 10; % default fallback
            end
        end
        
        function tf = pathExists(obj, path)
            tf = obj.B.has(path); % Use BCT method
        end
    end
end
