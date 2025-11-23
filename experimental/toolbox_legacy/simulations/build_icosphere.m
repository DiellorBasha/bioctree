function G = build_icosphere(subdiv, R, opts)
% BUILD_ICOSPHERE  Mesh + graph from FileExchange `icosphere`.
% Requires icosphere.m on your path.
arguments
    subdiv (1,1) {mustBeInteger,mustBeNonnegative} = 3
    R (1,1) double = 1
    opts.laplacianType (1,1) string {mustBeMember(opts.laplacianType,["cotangent","combinatorial"])} = "cotangent"
    opts.edgeWeightSigmaDeg (1,1) double = 0    % used only for combinatorial
end

% --- Mesh ---
[V,F] = icosphere(subdiv);   % unit sphere
V = R * V;

% --- Vertex areas (1/3 of incident face areas) ---
% Triangle areas via 0.5 * || (p2-p1) x (p3-p1) ||
u = V(F(:,2),:) - V(F(:,1),:);
v = V(F(:,3),:) - V(F(:,1),:);
faceAreas = 0.5 * vecnorm(cross(u, v, 2), 2, 2);   % <-- fixed parentheses
N = size(V,1);
Avert = accumarray(F(:), repmat(faceAreas/3, 3, 1), [N,1]);

% --- Graph operator ---
E = [F(:,[1,2]); F(:,[2,3]); F(:,[3,1])];
E = unique(sort(E,2),'rows');

switch opts.laplacianType
    case "cotangent"
        L = cotangent_laplacian(V,F);   % LB-like
        W = [];                         % not used
        A = [];                         % not used for cotangent

    case "combinatorial"
        if opts.edgeWeightSigmaDeg > 0
            % geodesic-Gaussian edge weights
            r1 = V(E(:,1),:); r2 = V(E(:,2),:);
            cs = max(-1, min(1, sum(r1.*r2,2)/(R^2)));
            ang = real(acos(cs));
            sigma = deg2rad_safe(opts.edgeWeightSigmaDeg);
            w = exp(-0.5 * (ang/sigma).^2);
        else
            w = ones(size(E,1),1);
        end
        W = sparse(E(:,1),E(:,2),w,N,N); W = W + W.';
        A = W > 0;  % Logical adjacency matrix
        d = sum(W,2);
        L = spdiags(d,0,N,N) - W;
end

% Create GSPBox-compatible structure
G = struct();

% GSPBox standard fields
G.N = N;                        % Number of vertices (GSPBox standard)
G.coords = V;                   % Vertex coordinates (GSPBox standard)
G.W = W;                        % Weight matrix (GSPBox standard)
G.L = L;                        % Laplacian matrix (GSPBox standard)

% Additional GSPBox fields
if ~isempty(W)
    G.A = A;                    % Adjacency matrix
    G.d = sum(W, 2);           % Degree vector
    G.Ne = nnz(W) / 2;         % Number of edges (undirected)
else
    % For cotangent Laplacian, create adjacency from edges
    G.A = sparse(E(:,1), E(:,2), true, N, N);
    G.A = G.A + G.A.';         % Make symmetric
    G.d = sum(G.A, 2);         % Degree vector (unweighted)
    G.Ne = size(E, 1);         % Number of edges
end

G.directed = 0;                 % Undirected graph
G.hypergraph = 0;              % Not a hypergraph
G.lap_type = char(opts.laplacianType);  % Laplacian type
G.type = 'icosphere';          % Graph type identifier

% Mesh-specific fields (for compatibility with existing code)
G.V = V;                       % Vertex coordinates (alternative naming)
G.F = F;                       % Face connectivity
G.E = E;                       % Edge connectivity  
G.R = R;                       % Sphere radius
G.vertexArea = Avert;          % Vertex areas

% GSPBox plotting structure (basic)
G.plotting = struct();
G.plotting.vertex_size = 30;
G.plotting.vertex_color = [0.8, 0.9, 1.0];
G.plotting.edge_color = [0.5, 0.5, 0.5];
G.plotting.edge_width = 0.5;
end

% ---------- helpers ----------
function L = cotangent_laplacian(V,F)
N = size(V,1);
I=[]; J=[]; S=[];
for t=1:size(F,1)
    idx = F(t,:); v = V(idx,:);
    e1 = v(2,:)-v(1,:); e2 = v(3,:)-v(2,:); e3 = v(1,:)-v(3,:);
    a1 = angle_between(-e3, e1);
    a2 = angle_between(-e1, e2);
    a3 = angle_between(-e2, e3);
    c12 = cot(a3); c23 = cot(a1); c31 = cot(a2);
    w = [0 c12 c31; c12 0 c23; c31 c23 0];
    [ii,jj] = ndgrid(idx,idx);
    I = [I; ii(:)]; J = [J; jj(:)]; S = [S; -w(:)];
end
L = sparse(I,J,S,N,N);
L = L - spdiags(sum(L,2),0,N,N);   % fix diagonal
end

function a = angle_between(u,v)
a = acos( max(-1,min(1, dot(u,v,2)./(vecnorm(u,2,2).*vecnorm(v,2,2)) )) );
end

function r = deg2rad_safe(d)
if exist('deg2rad','file')
    r = deg2rad(d);
else
    r = d * pi/180;
end
end
