classdef Manifold < handle
    properties
        Type (1,1) string {mustBeMember(Type,["mesh","graph"])} = "graph"
        % --- Mesh data ---
        V double = []     % N×3
        F double = []     % T×3
        % --- Graph data ---
        Edges table = table(zeros(0,2), zeros(0,1), ...
                            'VariableNames',{'EndNodes','Weight'})
        N (1,1) double {mustBeInteger,mustBeNonnegative} = 0
        % --- Time data (optional, for time-varying signals) ---
        Time bct.manifold.Time = bct.manifold.Time.empty()  % Time dimension properties
    end

    properties (Access=private)
        Cache struct = struct()   % operators, spectral, etc.
    end
    
    properties (SetAccess=private)
        % Mesh Fourier basis (cached from meshFourier method)
        Eigenvectors double = []    % U: N×k matrix of eigenvectors (Fourier basis)
        Eigenvalues double = []     % lam: k×1 vector of eigenvalues (spatial frequencies)
        NumModes (1,1) double {mustBeInteger,mustBeNonnegative} = 0  % k: number of computed modes
        MassMatrix = []             % M: N×N sparse diagonal mass matrix
        LaplacianType string = ""   % Type of Laplacian used ("cotangent", "combinatorial", etc.)
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
        
        function [U, lam, K, M, D, Ls] = meshFourier(obj, k, opts)
            % meshFourier - Compute and cache Fourier basis of the mesh manifold
            %
            % Computes the eigendecomposition of the normalized cotangent Laplacian
            % and stores the eigenvectors, eigenvalues, and mass matrix as properties.
            %
            % Syntax:
            %   [U, lam] = obj.meshFourier()
            %   [U, lam] = obj.meshFourier(k)
            %   [U, lam] = obj.meshFourier(k, opts)
            %   [U, lam, K, M, D, Ls] = obj.meshFourier(...)
            %
            % Inputs:
            %   k    - (optional) Number of modes to compute
            %          Default: min(600, NumVertices-1)
            %   opts - (optional) Structure with fields:
            %          .tol     - Convergence tolerance (default: 1e-10)
            %          .maxit   - Maximum iterations (default: 5000)
            %          .sigma   - Eigenvalue shift (default: 1e-6)
            %
            % Outputs:
            %   U   - [N×k] eigenvectors (also stored in obj.Eigenvectors)
            %   lam - [k×1] eigenvalues (also stored in obj.Eigenvalues)
            %   K   - [N×N] sparse cotangent Laplacian (stiffness)
            %   M   - [N×N] sparse mass matrix (also stored in obj.MassMatrix)
            %   D   - [k×k] diagonal eigenvalue matrix
            %   Ls  - [N×N] normalized Laplacian
            %
            % Side Effects:
            %   - Sets obj.Eigenvectors, obj.Eigenvalues, obj.NumModes
            %   - Sets obj.MassMatrix
            %   - Sets obj.LaplacianType to "cotangent"
            %   - Updates obj.Cache with K matrix
            %
            % See also: bct.manifold.Manifold.eigenpairs
            
            if obj.Type ~= "mesh"
                error('Manifold:InvalidType', 'meshFourier only works for mesh manifolds');
            end
            
            nVerts = size(obj.V, 1);
            
            % Default number of modes
            if nargin < 2 || isempty(k)
                k = min(200, nVerts - 1);
            end
            
            % Validate k
            if k < 1 || k >= nVerts
                error('Manifold:InvalidK', 'k must be between 1 and NumVertices-1 (got k=%d, N=%d)', k, nVerts);
            end
            
            % Default options
            if nargin < 3 || isempty(opts)
                opts = struct();
            end
            if ~isfield(opts, 'tol'),     opts.tol = 1e-10; end
            if ~isfield(opts, 'maxit'),   opts.maxit = 5000; end
            if ~isfield(opts, 'sigma'),   opts.sigma = 1e-6; end
            if ~isfield(opts, 'isreal'),  opts.isreal = true; end
            
            % Check for gptoolbox
            if ~hasGptoolbox()
                error('Manifold:MissingDependency', ...
                    'meshFourier requires gptoolbox (cotmatrix, massmatrix functions)');
            end
            
            % Compute cotangent Laplacian and mass matrix
            K = -cotmatrix(obj.V, obj.F);                      % PSD stiffness
            M = massmatrix(obj.V, obj.F, 'barycentric');       % diagonal mass
            K = (K + K.') / 2;                                 % enforce symmetry
            d = full(diag(M));
            M = spdiags(d, 0, length(d), length(d));
            
            % Normalized Laplacian
            Sinv = spdiags(1./sqrt(d), 0, length(d), length(d));
            Ls = (Sinv * K * Sinv);
            Ls = (Ls + Ls.') / 2;
            
            % Eigen solve near zero with shift-invert
            [U, D] = eigs(Ls, k, opts.sigma, opts);
            lam = real(diag(D));
            
            % Clean numerical fuzz
            tol = 1e-10 * max(1, max(abs(lam)));
            lam(lam < 0 & lam > -tol) = 0;
            
            % Drop DC and any negatives beyond tolerance
            mask = lam > tol;
            lam = lam(mask);
            U = U(:, mask);
            D = D(mask, mask);
            
            % Store in object properties
            obj.Eigenvectors = U;
            obj.Eigenvalues = lam;
            obj.NumModes = length(lam);
            obj.MassMatrix = M;
            obj.LaplacianType = "cotangent";
            
            % Update cache with K matrix (cotangent Laplacian)
            obj.Cache.K = K;
            obj.Cache.M = M;
            obj.Cache.L_cotangent = K;  % Store cotangent form explicitly
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
