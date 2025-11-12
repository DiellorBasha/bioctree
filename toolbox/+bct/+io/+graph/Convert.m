classdef Convert
  methods (Static)
        function snap = freeSurferRawToSnapshot(raw)
      V = raw.V; F = raw.F;
      if size(F,2)==4        % triangulate quads by default
        a=F(:,1); b=F(:,2); c=F(:,3); d=F(:,4);
        F = [a b c; a c d];
      end
      snap = struct('V',double(V),'F',int32(F), 'meta',raw.meta);
    end
      function snap = fromRaw(raw, kind, opts)
      if nargin<3, opts = struct(); end
      if ~isfield(opts,'TriangulateQuads'), opts.TriangulateQuads = true; end
      if ~isfield(opts,'verbose'),          opts.verbose          = 0;    end

      switch kind
        case 'freesurfer_surf'
          V = raw.V; F = raw.F;
          if raw.isQuad && opts.TriangulateQuads
            F = bct.io.graph.Convert.triangulateQuads(F);
          end
          snap = struct('V', V, 'F', F, 'meta', raw.meta);

        % other kinds (triangulation, MATLAB graph, adjacency, etc.)
        % live here too—but *not* in `In`.
        otherwise
          error('bct:Convert:UnknownKind','Unknown raw kind: %s', kind);
      end
    end

    function Ft = triangulateQuads(Fq)
      if isempty(Fq) || size(Fq,2) ~= 4, Ft = Fq; return; end
      a = Fq(:,1); b = Fq(:,2); c = Fq(:,3); d = Fq(:,4);
      Ft = [a b c; a c d];
    end
  end
end
