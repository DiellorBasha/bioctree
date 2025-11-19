classdef Manifold < handle
    properties
        Type (1,1) string {mustBeMember(Type,["mesh","graph"])} = "graph"
        % --- Mesh data ---
        V double = []     % N×3
        F double = []     % T×3
        UV double = []    % N×2 UV parametrization (from spherical registration)
        Units (1,1) string = "mm"  % Spatial units for V coordinates (default: mm)
        % --- Graph data ---
        Edges table = table(zeros(0,2), zeros(0,1), ...
                            'VariableNames',{'EndNodes','Weight'})
        N (1,1) double {mustBeInteger,mustBeNonnegative} = 0
        % --- Time data (optional, for time-varying signals) ---
        Time bct.manifold.Time = bct.manifold.Time.empty()  % Time dimension properties
    end

    properties (Access=protected)
        Cache struct = struct()   % operators, spectral, etc.
    end
    
    properties (SetAccess=private)
        % Mesh Fourier basis (cached from meshFourier method)
        Eigenvectors double = []    % U: N×k matrix of eigenvectors (Fourier basis)
        Eigenvalues double = []     % lam: k×1 vector of eigenvalues (spatial frequencies)
        NumModes (1,1) double {mustBeInteger,mustBeNonnegative} = 0  % k: number of computed modes
        MassMatrix = []             % M: N×N sparse diagonal mass matrix
        Laplacian = []              % L: N×N sparse Laplacian matrix (cotangent for mesh, combinatorial for graph)
        CotangentMatrix = []        % K: N×N sparse cotangent stiffness matrix (for mesh only, K = M*L)
        LaplacianType string = ""   % Type of Laplacian used ("cotangent", "combinatorial", etc.)
        
        % Spatial resolution manager (for mesh manifolds)
        Resolution bct.resolution.spatial = bct.resolution.spatial.empty()  % Spatial resolution object
    end

    methods
        %% ---------- Constructors ----------
        function obj = Manifold(varargin)
            if nargin==0, return; end
            if nargin==2 && size(varargin{1},2)==3 && size(varargin{2},2)==3
                obj.Type = "mesh"; 
                obj.V = varargin{1}; 
                obj.F = varargin{2}; 
                obj.N = size(obj.V, 1);  % Number of vertices
                % Initialize Laplacian, MassMatrix, and CotangentMatrix using bct.manifold.laplacian
                [obj.Laplacian, obj.MassMatrix, obj.CotangentMatrix] = bct.manifold.laplacian(obj.V, obj.F, "cotangent");
                obj.LaplacianType = "cotangent";
                % Cache matrices for backward compatibility
                obj.Cache.K = obj.CotangentMatrix;
                obj.Cache.M = obj.MassMatrix;
                obj.Cache.L_cotangent = obj.Laplacian;
                
                % Compute lambda_max_full for Resolution property
                % Build normalized Laplacian for spectral analysis
                d = full(diag(obj.MassMatrix));
                Sinv = spdiags(1./sqrt(d), 0, length(d), length(d));
                Ls = Sinv * obj.CotangentMatrix * Sinv;
                Ls = (Ls + Ls.') / 2;
                
                % Compute maximum eigenvalue
                try
                    lambda_max_opts = struct();
                    lambda_max_opts.tol = 5e-3;
                    lambda_max_opts.p = min(size(Ls,1), 10);
                    lambda_max_opts.disp = 0;
                    lambda_max_full = eigs(Ls, 1, 'largestabs', lambda_max_opts);
                    lambda_max_full = real(lambda_max_full) * 1.01;  % 1% safety margin
                catch
                    % Fallback to power iteration if eigs fails
                    lambda_max_full = powerIterLargestEig(Ls, 20);
                end
                obj.Cache.lambda_max_full = lambda_max_full;
                
                % Create spatial resolution object
                obj.Resolution = bct.resolution.spatial(obj);
                return
            end
            if nargin==1
                X = varargin{1};
                if istable(X)
                    obj.Type = "graph"; obj.N = max(X.EndNodes,[],'all'); obj.Edges = normalizeEdgesTable(X); return
                elseif ismatrix(X) && size(X,1)==size(X,2)
                    obj.Type = "graph"; obj.N = size(X,1); obj.Edges = edgesFromAdjacency(X); return
                else
                    error('Manifold:BadInput', 'Use (V,F) for mesh, or (Edges) / (A) for graph.');
                end
            end
            if nargin==2
                N = varargin{1}; X = varargin{2};
                if ~(isscalar(N) && isnumeric(N))
                    error('Manifold:BadInput','When two args, first must be scalar N.');
                end
                if istable(X)
                    obj.Type="graph"; obj.N = max(N, max(X.EndNodes,[],'all')); obj.Edges = normalizeEdgesTable(X); return
                elseif ismatrix(X) && size(X,1)==size(X,2)
                    obj.Type="graph"; obj.N = max(N, size(X,1)); obj.Edges = edgesFromAdjacency(X); return
                else
                    error('Manifold:BadInput','Second arg must be Edges table or adjacency matrix.');
                end
            end
        end

        %% ---------- Public API ----------
        function A = adjacency(obj)
            if obj.Type=="graph"
                A = i_cache(obj,"A",@() adjacency(graph(obj.Edges)));
            else
                [K,~] = obj.stiffnessMass();  % K ≈ D-W (up to sign)
                A = i_cache(obj,"A_mesh",@() spdiags(-diag(K),0,size(K,1),size(K,2)) + K);
            end
        end
        
        function W = weightedAdjacency(obj)
            %WEIGHTEDADJACENCY Compute weighted adjacency matrix from cotangent matrix
            %
            %   W = obj.weightedAdjacency() returns the weighted adjacency matrix
            %   for mesh manifolds, derived from the cotangent stiffness matrix K.
            %
            %   The weighted adjacency matrix W is computed as:
            %       W = -K with diagonal entries set to zero
            %
            %   For mesh manifolds, the cotangent weights represent geometric
            %   relationships between adjacent vertices. The negative of K gives
            %   positive edge weights.
            %
            %   Returns:
            %       W - N×N sparse weighted adjacency matrix with positive weights
            %
            %   See also: adjacency, CotangentMatrix
            
            if obj.Type ~= "mesh"
                error('Manifold:InvalidType', 'weightedAdjacency only works for mesh manifolds');
            end
            
            if isempty(obj.CotangentMatrix)
                error('Manifold:NoCotangentMatrix', 'CotangentMatrix not computed. Call meshFourier first.');
            end
            
            % Compute weighted adjacency from cotangent matrix
            W = i_cache(obj, "W_mesh", @() computeWeightedAdjacency(obj.CotangentMatrix));
        end

        function L = laplacian(obj, form)
            if nargin<2, form = ""; end; form = string(form);
            if obj.Type=="graph"
                if form=="" || form=="combinatorial"
                    L = i_cache(obj,"L_graph_comb",@() laplacian(graph(obj.Edges)));
                elseif form=="normalized" || form=="normsym"
                    L = i_cache(obj,"L_graph_norm",@() normalizedGraphLaplacian(obj.Edges, obj.N));
                else
                    error('Manifold:Form','Unknown graph laplacian form: %s', form);
                end
            else
                [K,M] = obj.stiffnessMass();
                if form=="symmetric"
                    L = i_cache(obj,"L_mesh_sym",@() symNormalize(K,M));
                else
                    % default "LB": unsymmetric apply form M^{-1}K
                    L = i_cache(obj,"L_mesh_LB",@() (M\K));
                end
            end
        end

        function I = incidence(obj)
            if obj.Type=="graph"
                I = i_cache(obj,"I_graph",@() incidence(graph(obj.Edges)));
            else
                I = i_cache(obj,"I_mesh",@() incidenceFromFaces(obj.F, size(obj.V,1)));
            end
        end

        function D = degree(obj)
            if obj.Type=="graph"
                d = i_cache(obj,"deg_graph",@() degree(graph(obj.Edges)));
                D = spdiags(d,0,max(obj.N,numel(d)),max(obj.N,numel(d)));
            else
                [~,M] = obj.stiffnessMass();
                D = i_cache(obj,"deg_mesh",@() spdiags(full(diag(M)),0,size(M,1),size(M,2)));
            end
        end

        %% ---------- Spectral API with caching ----------
        function [Phi, lambda] = eigenpairs(obj, k, form)
            if nargin<2, k = 50; end
            if nargin<3
                form = obj.defaultSpectralForm();
            end
            form = string(form);
            key = spectralKey(obj, form);

            if ~isfield(obj.Cache,'Spectral') || ~isfield(obj.Cache.Spectral, key) ...
               || obj.Cache.Spectral.(key).k < k
                % (Re)compute with larger k and store
                [Phi, lambda] = computeEigenpairs(obj, k, form);
                S.k = numel(lambda);
                S.Phi = Phi;           % N×k
                S.lambda = lambda(:);  % k×1
                obj.Cache.Spectral.(key) = S;
            else
                S = obj.Cache.Spectral.(key);
                Phi    = S.Phi(:,1:k);
                lambda = S.lambda(1:k);
            end
        end

        function lamMax = lambdaMax(obj, form)
            if nargin<2, form = obj.defaultSpectralForm(); end
            form = string(form);
            key = ['lamMax__' spectralKey(obj,form)];
            if isfield(obj.Cache, key), lamMax = obj.Cache.(key); return; end

            if obj.Type=="graph"
                if form=="normalized" || form=="normsym"
                    lamMax = 2;  % spectrum in [0,2] for normalized Laplacian
                else
                    L = obj.laplacian("combinatorial");
                    lamMax = powerIterLargestEig(L, 20);
                end
            else
                % For mesh: use symmetric form as upper bound for all forms
                % (including "LB" M^{-1}K form, where symmetric gives Gershgorin-ish bound)
                Ls = obj.laplacian("symmetric");
                lamMax = powerIterLargestEig(Ls, 20);
            end
            obj.Cache.(key) = lamMax;
        end

        function clearCache(obj)
            obj.Cache = struct();
        end
        
        function hasUV = checkUV(obj, throw_error)
            %CHECKUV Check if UV parametrization is available
            %
            %   hasUV = obj.checkUV() returns true if UV parametrization exists
            %   hasUV = obj.checkUV(true) throws error if UV is missing
            %
            %   UV parametrization is optional and typically comes from FreeSurfer
            %   spherical registration (.sphere.reg files). If not available, this
            %   method can warn or error depending on usage context.
            %
            %   See also: bct.io.import.mesh, bct.io.import.computeUVFromSphere
            
            if nargin < 2
                throw_error = false;
            end
            
            hasUV = ~isempty(obj.UV);
            
            if ~hasUV
                msg = ['UV parametrization not available for this Manifold. ', ...
                       'UV coordinates are typically loaded from FreeSurfer .sphere.reg files. ', ...
                       'To use UV-based functions, import a FreeSurfer surface with spherical registration.'];
                
                if throw_error
                    error('bct:Manifold:NoUV', msg);
                else
                    warning('bct:Manifold:NoUV', msg);
                end
            end
        end
        
        function lambda_max = getLambdaMaxFull(obj)
            %GETLAMBDAMAXFULL Get cached full maximum eigenvalue
            %
            %   lambda_max = obj.getLambdaMaxFull() returns the cached
            %   full maximum eigenvalue from the Laplacian, or empty if
            %   not yet computed.
            %
            %   This is used by bct.resolution.spatial to access the
            %   full maximum eigenvalue computed during meshFourier().
            
            if isfield(obj.Cache, 'lambda_max_full')
                lambda_max = obj.Cache.lambda_max_full;
            else
                lambda_max = [];
            end
        end
        
        function [U, lam] = meshFourier(obj, numModes, opts)
            % meshFourier - Compute and cache Fourier basis of the mesh manifold
            %
            % Computes the eigendecomposition of the mesh Laplacian using the
            % appropriate eigensolver based on the LaplacianType property.
            %
            % Syntax:
            %   obj.meshFourier()              % Compute default modes, results in properties
            %   obj.meshFourier(numModes)      % Compute numModes modes
            %   [U, lam] = obj.meshFourier(numModes, opts)  % Also return eigenpairs
            %
            % Inputs:
            %   numModes - (optional) Number of modes to compute
            %              Default: min(200, NumVertices-1)
            %   opts     - (optional) Structure with fields:
            %              .tol         - Convergence tolerance (default: 1e-10)
            %              .maxit       - Maximum iterations (default: 5000)
            %              .sigma       - Eigenvalue target/shift (default: 1e-6)
            %                             For mode='smallestabs', finds numModes eigenvalues
            %                             closest to sigma
            %              .mode        - Eigensolver mode (default: 'smallestreal')
            %                             'smallestreal' - numModes smallest eigenvalues
            %                             'smallestabs'  - numModes eigenvalues closest to sigma
            %              .lambda_low  - (optional) Lower bound for band filtering
            %              .lambda_high - (optional) Upper bound for band filtering
            %                             If both specified, only eigenvalues in
            %                             [lambda_low, lambda_high] are returned
            %
            % Outputs (optional):
            %   U   - [N×numModes] eigenvectors (same as obj.Eigenvectors)
            %   lam - [numModes×1] eigenvalues (same as obj.Eigenvalues)
            %
            % Note: All matrices (K, M, L) are available as properties:
            %   obj.CotangentMatrix - K
            %   obj.MassMatrix - M
            %   obj.Laplacian - L
            %
            % Eigensolver Selection:
            %   - If LaplacianType is "cotangent": Uses generalized eigenproblem
            %     eigs(K, M, k, sigma) which is optimal for FEM meshes
            %   - If LaplacianType contains "normalized": Uses standard eigenproblem
            %     eigs(L, k, sigma) on the normalized Laplacian
            %
            % Side Effects:
            %   - Sets obj.Eigenvectors, obj.Eigenvalues, obj.NumModes
            %
            % See also: bct.manifold.Manifold.eigenpairs, bct.manifold.laplacian
            
            if obj.Type ~= "mesh"
                error('Manifold:InvalidType', 'meshFourier only works for mesh manifolds');
            end
            
            nVerts = size(obj.V, 1);
            
            % Default number of modes
            if nargin < 2 || isempty(numModes)
                numModes = min(200, nVerts - 1);
            end
            
            % Validate numModes
            if numModes < 0 || numModes >= nVerts
                error('Manifold:InvalidNumModes', 'numModes must be between 0 and NumVertices-1 (got numModes=%d, N=%d)', numModes, nVerts);
            end
            
            % Default options
            if nargin < 3 || isempty(opts)
                opts = struct();
            end
            if ~isfield(opts, 'tol'),         opts.tol = 1e-10; end
            if ~isfield(opts, 'maxit'),       opts.maxit = 5000; end
            if ~isfield(opts, 'sigma'),       opts.sigma = 1e-6; end
            if ~isfield(opts, 'mode'),        opts.mode = 'smallestreal'; end
            if ~isfield(opts, 'lambda_low'),  opts.lambda_low = []; end
            if ~isfield(opts, 'lambda_high'), opts.lambda_high = []; end
            if ~isfield(opts, 'isreal'),      opts.isreal = true; end
            if ~isfield(opts, 'issym'),       opts.issym = true; end
            
            % Get matrices from properties (already computed in constructor)
            if isempty(obj.MassMatrix) || isempty(obj.CotangentMatrix)
                error('Manifold:NoMatrices', ...
                    'MassMatrix and CotangentMatrix must be computed first (should happen in constructor)');
            end
            
            M = obj.MassMatrix;
            K = obj.CotangentMatrix;
            
            % If numModes=0, skip eigenmode computation (matrix-only mode)
            if numModes == 0
                obj.Eigenvectors = [];
                obj.Eigenvalues = [];
                obj.NumModes = 0;
                U = [];
                lam = [];
                return;
            end
            
            % Select eigensolver based on LaplacianType
            if obj.LaplacianType == "cotangent"
                % Generalized eigenproblem: K*U = M*U*D
                % This is the optimal form for FEM meshes
                % Eigenvalues are with respect to the cotangent Laplacian
                [U, D] = eigs(K, M, numModes, opts.sigma, opts);
                lam = real(diag(D));
                
                % Sort by eigenvalue (eigs with 'smallestabs' may not return sorted)
                if strcmp(opts.mode, 'smallestabs')
                    [lam, idx] = sort(lam, 'ascend');
                    U = U(:, idx);
                    D = D(idx, idx);
                end
                
            elseif contains(obj.LaplacianType, "normalized")
                % Standard eigenproblem on normalized Laplacian: L*U = U*D
                % L = M^{-1/2} * K * M^{-1/2} (symmetric normalized form)
                if isempty(obj.Laplacian)
                    error('Manifold:NoLaplacian', ...
                        'Laplacian matrix not available for normalized type');
                end
                
                [U, D] = eigs(obj.Laplacian, numModes, opts.sigma, opts);
                lam = real(diag(D));
                
                % Sort by eigenvalue (eigs with 'smallestabs' may not return sorted)
                if strcmp(opts.mode, 'smallestabs')
                    [lam, idx] = sort(lam, 'ascend');
                    U = U(:, idx);
                    D = D(idx, idx);
                end
                
            else
                error('Manifold:UnknownLaplacianType', ...
                    'Unknown LaplacianType: %s. Expected "cotangent" or type containing "normalized"', ...
                    obj.LaplacianType);
            end
            
            % Clean numerical fuzz
            tol = 1e-10 * max(1, max(abs(lam)));
            lam(lam < 0 & lam > -tol) = 0;
            
            % Remove only negative eigenvalues (keep λ=0 and all positive modes)
            % This preserves the constant eigenfunction (λ₀=0) and low-frequency modes
            % needed for global waves and diffusion wavelet kernels
            mask = lam >= -tol;
            
            % Apply band filtering if lambda_low and lambda_high are specified
            if ~isempty(opts.lambda_low) && ~isempty(opts.lambda_high)
                band_mask = (lam >= opts.lambda_low) & (lam <= opts.lambda_high);
                mask = mask & band_mask;
            end
            
            lam = lam(mask);
            U = U(:, mask);
            D = D(mask, mask);
            
            % Store eigenmodes in object properties
            obj.Eigenvectors = U;
            obj.Eigenvalues = lam;
            obj.NumModes = length(lam);
        end
    end

    %% ---------- Mesh backends ----------
    methods (Access=private)
        function [K,M] = stiffnessMass(obj)
            if ~isfield(obj.Cache,'K') || ~isfield(obj.Cache,'M')
                if hasGptoolbox()
                    K = cotmatrix(obj.V,obj.F);
                    M = massmatrix(obj.V,obj.F,'barycentric');   % or 'voronoi'
                else
                    [K,M] = cotangentFallback(obj.V,obj.F);
                end
                obj.Cache.K = K; obj.Cache.M = M;
                % invalidate mesh spectral caches if K/M change
                if isfield(obj.Cache,'Spectral')
                    fns = fieldnames(obj.Cache.Spectral);
                    for i=1:numel(fns)
                        if startsWith(fns{i},'mesh_'), obj.Cache.Spectral = rmfield(obj.Cache.Spectral,fns{i}); end
                    end
                end
            end
            K = obj.Cache.K; M = obj.Cache.M;
        end

        function [Phi, lambda] = computeEigenpairs(obj, k, form)
            if obj.Type=="graph"
                if form=="" || form=="combinatorial"
                    L = obj.laplacian("combinatorial");
                    [Phi,D] = eigs(L, k, 'SM');
                    lambda  = diag(D);
                elseif form=="normalized" || form=="normsym"
                    L = obj.laplacian("normalized");
                    [Phi,D] = eigs(L, k, 'SM');
                    lambda  = diag(D);
                else
                    error('Manifold:Form','Unknown graph spectral form: %s', form);
                end
            else
                [K,M] = obj.stiffnessMass();
                if form=="symmetric"
                    Ls = obj.laplacian("symmetric");
                    [Phi,D] = eigs(Ls, k, 'SM');
                    lambda  = diag(D);
                else % default "LB" generalized problem
                    opts.isreal = true; opts.issym = true;
                    [Phi,D] = eigs(K, M, k, 'SM', opts);
                    lambda  = diag(D);
                end
            end
        end

        function key = spectralKey(obj, form)
            if obj.Type=="graph"
                if form=="" || form=="combinatorial", key = 'graph_comb'; else, key = 'graph_norm'; end
            else
                if form=="symmetric", key = 'mesh_sym'; else, key = 'mesh_LB'; end
            end
        end
        
        function form = defaultSpectralForm(obj)
            % Return default spectral form based on manifold type
            if obj.Type == "graph"
                form = "combinatorial";
            else
                form = "symmetric";  % Default to symmetric normalized for mesh
            end
        end

    end
end

%% ================= helpers =================
function E = edgesFromAdjacency(A)
[i,j,v] = find(triu(A,1));
if isempty(v), v = ones(numel(i),1); end
E = table([i j], double(v), 'VariableNames',{'EndNodes','Weight'});
end

function T = normalizeEdgesTable(T)
if ~ismember('EndNodes',T.Properties.VariableNames)
    error('Edges table must contain variable "EndNodes" (Mx2).');
end
if ~ismember('Weight',T.Properties.VariableNames)
    T.Weight = ones(height(T),1);
end
T.EndNodes = double(T.EndNodes);
T.Weight  = double(T.Weight);
end

function A = i_cache(obj,key,f)
if isfield(obj.Cache,key), A = obj.Cache.(key); return; end
A = f(); obj.Cache.(key) = A;
end

function Ls = symNormalize(K,M)
d = full(diag(M)); d(d==0)=1;
Sinv = spdiags(1./sqrt(d),0,length(d),length(d));
Ls = Sinv * K * Sinv;
end

function I = incidenceFromFaces(F, N)
if isempty(F), I = sparse(N,0); return; end
E = sort([F(:,[1 2]); F(:,[2 3]); F(:,[3 1])],2);
E = unique(E,'rows');
m = size(E,1);
I = sparse([E(:,1);E(:,2)], repmat((1:m).',2,1), [ones(m,1); -ones(m,1)], N, m);
end

function tf = hasGptoolbox()
tf = exist('cotmatrix','file')==2 && exist('massmatrix','file')==2;
end

function [K,M] = cotangentFallback(V,F)
N = size(V,1); T = size(F,1);
I = []; J = []; S = [];
Ml = zeros(N,1);
for t=1:T
    f = F(t,:);
    v1 = V(f(1),:); v2 = V(f(2),:); v3 = V(f(3),:);
    e1 = v2 - v3; e2 = v3 - v1; e3 = v1 - v2;
    c1 = dot(e2,-e3)/norm(cross(e2,-e3));
    c2 = dot(e3,-e1)/norm(cross(e3,-e1));
    c3 = dot(e1,-e2)/norm(cross(e1,-e2));
    w12 = 0.5*c3; w23 = 0.5*c1; w31 = 0.5*c2;
    I = [I; f(1); f(2); f(2); f(3); f(3); f(1)];
    J = [J; f(2); f(1); f(3); f(2); f(1); f(3)];
    S = [S; -w12; -w12; -w23; -w23; -w31; -w31];
    Atri = 0.5*norm(cross(v2-v1,v3-v1));
    Ml(f) = Ml(f) + Atri/3;
end
K = sparse(I,J,S,N,N);
K = K - spdiags(sum(K,2),0,N,N);
M = spdiags(Ml,0,N,N);
end

function L = normalizedGraphLaplacian(Edges, N)
% Build L_sym = I - D^{-1/2} W D^{-1/2} from edges table
E = double(Edges.EndNodes);
w = double(Edges.Weight);
W = sparse([E(:,1);E(:,2)], [E(:,2);E(:,1)], [w; w], N, N);
d = sum(W,2);
Dinv2 = spdiags(1./sqrt(max(d,eps)), 0, N, N);
L = speye(N) - Dinv2 * W * Dinv2;
end

function lam = powerIterLargestEig(L, iters)
n = size(L,1);
x = randn(n,1); x = x/norm(x);
for t=1:iters
    y = L*x;
    ny = norm(y);
    if ny==0, break; end
    x = y/ny;
end
lam = (x'*(L*x))/(x'*x);  % Rayleigh quotient
end

function W = computeWeightedAdjacency(K)
% Compute weighted adjacency matrix from cotangent stiffness matrix
% W = -K with diagonal entries zeroed out
W = -K;                           % off-diagonals become positive weights
W(1:size(W,1)+1:end) = 0;        % remove diagonal entries
end
