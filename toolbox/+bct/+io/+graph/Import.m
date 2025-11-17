classdef Import
  methods (Static)
    function B = fromFreeSurfer(path)
      raw  = bct.io.graph.In.readFreeSurferSurf(path);
      snap = bct.io.graph.Convert.freeSurferRawToSnapshot(raw);
      B    = bct.io.graph.Construct.buildBct(snap.V, snap.F, ManifoldType="graph");
      % if isfield(snap,'meta'), B.cache.meta = snap.meta; end
    end
    function B = fromBrainstorm(path, optsIn, optsCvt, optsBld)
      if nargin<2, optsIn  = struct(); end
      if nargin<3, optsCvt = struct(); end
      if nargin<4, optsBld = struct(); end

      raw  = bct.io.graph.In.readBrainstormAnat(path, optsIn);
      snap = bct.io.graph.Convert.fromRaw(raw, optsCvt);
      B    = bct.io.graph.Construct.buildBct(snap, optsBld);
    end

    function B = fromFile(path, optsIn, optsCvt, optsBld)
      if nargin<2, optsIn  = struct(); end
      if nargin<3, optsCvt = struct(); end
      if nargin<4, optsBld = struct(); end

      % auto-detect (reuse Convert lookups or add dedicated detector)
      if bct.io.graph.Convert.looksLikeFreeSurfer(path)
        B = bct.io.graph.Import.fromFreeSurfer(path, optsIn, optsCvt, optsBld);
      elseif bct.io.graph.Convert.looksLikeBrainstorm(path)
        B = bct.io.graph.Import.fromBrainstorm(path, optsIn, optsCvt, optsBld);
      else
        error('bct:Import:UnknownFormat','Cannot infer format from: %s', string(path));
      end
    end

    % Optional aliases
    function B = FreeSurfer(path, varargin), B = bct.io.graph.Import.fromFreeSurfer(path, varargin{:}); end
    function B = Brainstorm(path, varargin), B = bct.io.graph.Import.fromBrainstorm(path, varargin{:}); end
  end
end
