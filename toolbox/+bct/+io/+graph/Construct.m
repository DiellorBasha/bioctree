classdef Construct
  methods (Static)
    % ========= NEW: orchestrator to create an in-memory bct from (V,F) =========

    function B = buildBct(V, F, opts)
      % buildBct Build a bct object from vertices and faces
      %
      % Inputs:
      %   V - Nx3 vertices
      %   F - Mx3 faces
      %   opts.ManifoldType - 'mesh' (default) or 'graph'
      
      arguments
        V double
        F double
        opts.ManifoldType (1,1) string {mustBeMember(opts.ManifoldType, ["mesh", "graph"])} = "mesh"
      end
      
      % 1) Ensure outward normals (right-hand flip)
      if ~isempty(F), F = F(:,[1 3 2]); end

      % 2) Clean & make a surfaceMesh (normals, center, defects removal)
      mesh = bct.io.graph.Construct.makeCleanMesh(V, F,'Precenter',true,'RightHandFlip',false,'SkipNormals',false); % already flipped above
      
      % 3) Create Manifold based on requested type
      if opts.ManifoldType == "graph"
        % Extract edges from faces
        E = bct.io.graph.Construct.edgesFromFaces(mesh.Faces);
        
        % Create edges table with EndNodes as Mx2 matrix and default weights
        EdgesTable = table(double(E), ones(size(E,1),1), 'VariableNames', {'EndNodes', 'Weight'});
        
        % Create graph-type Manifold with edges
        manifold = bct.manifold.Manifold(size(mesh.Vertices,1), EdgesTable);
        % Store vertices for spatial embedding
        manifold.V = mesh.Vertices;
      else
        % Create mesh-type Manifold
        manifold = bct.manifold.Manifold(mesh.Vertices, mesh.Faces);
      end
      
      % 4) Create bct object with the Manifold
      B = bct.bct();
      B.Manifold = manifold;

      % Optionally tag cache/meta
      % B.cache.mesh = mesh;
      % if ~isfield(B.cache,'meta'), B.cache.meta = struct(); end
     % B.cache.meta.cleaned = true;
     % B.cache.meta.outward_normals = true;
    end
    % ========================= existing utilities =========================
    function A = cleanAdj(A)
      if ~issparse(A), A = sparse(A); end
      A = (A|A.'); A = A - diag(diag(A));
      A = spones(A)>0;
    end

    function W = cleanWeights(W)
      if ~issparse(W), W = sparse(W); end
      W = 0.5*(W+W.'); W = W - spdiags(diag(W),0,size(W,1),size(W,2));
      W = max(W,0);
    end

    function E = cleanEdges(E)
      E = double(E); if size(E,2)>2, E = E(:,1:2); end
      E = sort(E,2); E(E(:,1)==E(:,2),:) = [];
      E = unique(E,'rows'); E = int32(E);
    end

    function A = adjFromEdges(E, N)
      A = sparse(E(:,1),E(:,2),true,N,N); A = A + A.'; A = A - diag(diag(A));
      A = spones(A)>0;
    end

    function E = edgesFromAdj(A)
      [i,j] = find(triu(A,1)); E = int32([i j]);
    end

    function E = edgesFromFaces(F)
      e12 = sort(F(:,[1 2]),2); e23 = sort(F(:,[2 3]),2); e31 = sort(F(:,[3 1]),2);
      E = int32(unique([e12; e23; e31],'rows'));
    end

    function mesh = makeSurfaceMesh(V,F), mesh = surfaceMesh(V,F); end

    function Gg = makeMatlabGraph(W, V, directed)
      if nargin<3 || ~directed
        [i,j,w] = find(triu(W,1)); Gg = graph(i,j,w,size(W,1));
      else
        [i,j,w] = find(W);         Gg = digraph(i,j,w,size(W,1));
      end
      if ~isempty(V)
        Gg.Nodes.X = V(:,1); Gg.Nodes.Y = V(:,2);
        if size(V,2)>=3, Gg.Nodes.Z = V(:,3); end
      end
    end

    function G = makeGspGraph(Wund, V)
      if nargin>1 && ~isempty(V), G = gsp_graph(Wund, V); else, G = gsp_graph(Wund); end
      try G = gsp_estimate_lmax(G); catch, end
    end

    function snap = reconcileSnapshot(snap)
      if ~isfield(snap,'A') && isfield(snap,'W')
        snap.A = spones(0.5*(snap.W+snap.W.'))>0;
      end
      if ~isfield(snap,'E') && isfield(snap,'A')
        snap.E = bct.io.graph.Construct.edgesFromAdj(snap.A);
      end
      if ~isfield(snap,'A') && isfield(snap,'F')
        E = bct.io.graph.Construct.edgesFromFaces(snap.F);
        snap.E = E;
        snap.A = bct.io.graph.Construct.adjFromEdges(E, max(snap.F(:)));
      end
    end
  end

  methods (Static)
    function [W_cot, M] = cotangentWeights(V, F)
      V = double(V); F = double(F); N = size(V,1);
      i1 = F(:,1); i2 = F(:,2); i3 = F(:,3);
      v1 = V(i1,:); v2 = V(i2,:); v3 = V(i3,:);

      tri2A = vecnorm(cross(v2 - v1, v3 - v1, 2), 2, 2);
      denom = max(tri2A, eps);

      cotA = dot(v2 - v1, v3 - v1, 2) ./ denom;
      cotB = dot(v3 - v2, v1 - v2, 2) ./ denom;
      cotC = dot(v1 - v3, v2 - v3, 2) ./ denom;

      I = [i2; i3; i3; i1; i1; i2];
      J = [i3; i2; i1; i3; i2; i1];
      S = 0.5 * [cotA; cotA; cotB; cotB; cotC; cotC];

      W = sparse(I, J, S, N, N);
      W = 0.5*(W + W.');
      W = W - spdiags(diag(W),0,N,N);

      Mv = accumarray([i1; i2; i3], [tri2A; tri2A; tri2A]/6, [N 1], @sum, 0);
      M  = spdiags(Mv, 0, N, N);

      W_cot = W;
    end

function mesh = makeCleanMesh(V, F, varargin)
% makeCleanMesh(V,F, 'Precenter',true, 'RightHandFlip',false, 'SkipNormals',false)

% ---- validate requireds
validateattributes(V, {'numeric'}, {'2d','ncols',3,'finite','real'}, mfilename, 'V', 1);
validateattributes(F, {'numeric','integer'}, {'2d','ncols',3,'positive'}, mfilename, 'F', 2);
F = int32(F);                        % ensure integer indices
V = double(V);                       % ensure double coords

% ---- parse name-value opts
p = inputParser; p.FunctionName = mfilename;
addParameter(p, 'Precenter',    false, @(x)islogical(x)&&isscalar(x));
addParameter(p, 'RightHandFlip',false, @(x)islogical(x)&&isscalar(x));
addParameter(p, 'SkipNormals',  false, @(x)islogical(x)&&isscalar(x));
parse(p, varargin{:});
opts = p.Results;

% ---- apply options / build mesh
if opts.RightHandFlip
    F = F(:,[1 3 2]);               % outward normals for FS-style faces
end

mesh = surfaceMesh(V, F);

if ~opts.SkipNormals
    computeNormals(mesh);
end

if opts.Precenter
    ctr = vertexCenter(mesh);
    translate(mesh, -ctr, ctr);
end

% Robust cleanup passes (order matters)
removeDefects(mesh,"duplicate-vertices");
removeDefects(mesh,"duplicate-faces");
removeDefects(mesh,"unreferenced-vertices");
removeDefects(mesh,"degenerate-faces");
removeDefects(mesh,"nonmanifold-edges");
end


    function G = makeGspCotangent(V, F, W_cot, M)
      if nargin<3 || isempty(W_cot) || nargin<4 || isempty(M)
        [W_cot, M] = bct.io.graph.Construct.cotangentWeights(V,F);
      end
      G = gsp_graph(W_cot, V);
      G.Faces = int32(F);
      G.M     = M;
      G.plotting.vertex_size = 1;
      try G = gsp_estimate_lmax(G); catch, end
    end
  end
end
