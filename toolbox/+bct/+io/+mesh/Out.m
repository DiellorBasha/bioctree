classdef Out
  methods (Static)
    % Persist bct graph (uses @bct.write_graph, which delegates to +internal)
    function writeGraph(B, fn)
      Bout = bct.bct.open(fn);  %#ok<NASGU> % or .create(fn) depending on your flow
      % Let the class method pull E/coords/w from in-memory cache:
      B.write_graph(struct());  % as you wired earlier
    end

    % Exports to other ecosystems:
    function TR = toTriangulation(B)
      TR = triangulation(double(B.Faces), double(B.Vertices));
    end

    function Gg = toMatlabGraph(B, directed)
      if nargin<2, directed = B.directed; end
      W = B.getWeightsUndirected();        % tiny public getter in @bct
      Gg = bct.IO.Construct.makeMatlabGraph(W, B.Vertices, directed);
    end

    function G = toGsp(B)
      W = B.getWeightsUndirected();
      G  = bct.IO.Construct.makeGspGraph(W, B.Vertices);
    end
  end
  methods (Static)
  function writeGraphCotangent(B, outH5)
    % Writes the current in-memory mesh and (cotangent) edges into a BCT file.
    % If W not cached, build from Faces.
    if ~isfield(B.cache,'W') || isempty(B.cache.W)
      [W,~] = bct.io.graph.Construct.cotangentWeights(B.Vertices, B.Faces);
      B.cache.W = W;
    end
    % Build edge list + weights aligned to E
    A = spones(B.cache.W)>0; A = A - diag(diag(A));
    [i,j] = find(triu(A,1)); E = [i j];
    w = full(B.cache.W(sub2ind(size(B.cache.W), i, j)));

    Bout = bct.bct.create(outH5);
    Gfile = struct('E', int32(E), 'coords', B.Vertices, 'w', w, 'type', 'mesh-cotangent');
    Bout.write_graph(Gfile);
  end
end

end
