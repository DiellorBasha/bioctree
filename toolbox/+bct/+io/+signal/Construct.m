classdef Construct
% bct.io.signal.Construct
% Pure in-memory helpers for signals (no HDF5).

  methods (Static)
    function S = normalizeRaw(X, fs)
    % Ensure types/shapes for a raw (T x N) array.
      validateattributes(X, {'single','double'}, {'2d'});
      validateattributes(fs, {'numeric'}, {'scalar','positive'});
      S.X  = X;
      S.fs = double(fs);
      [S.T,S.N] = size(X);
    end

    function S = normalizeStack(Xltn, fs, layer_ids)
    % Ensure (L x T x N) stack and int32 layer ids.
      validateattributes(Xltn, {'single','double'}, {'3d'});
      [L,T,N] = size(Xltn);
      if nargin < 3 || isempty(layer_ids), layer_ids = int32(0:L-1); end
      layer_ids = int32(layer_ids(:));
      assert(numel(layer_ids)==L, 'bct:signal:LayerIdMismatch');
      S.Xltn      = Xltn;
      S.fs        = double(fs);
      S.layer_ids = layer_ids;
      S.L = L; S.T = T; S.N = N;
    end

    function axes = makeAxes(T, N, fs, L)
    % Build time/node (and optional layer) axes.
      t = (0:T-1)'/fs;
      node_id = int32((0:N-1)');
      if nargin < 4 || isempty(L)
        axes = struct('time_s',t,'node_id',node_id);
      else
        axes = struct('time_s',t,'node_id',node_id, ...
                      'layer_id',int32((0:L-1)'));
      end
    end

    function plan = framePlan(T, frameSec, hopSec, fs)
    % Compute start indices and counts for fixed-size frames.
      F = max(1, round(frameSec*fs));
      H = max(1, round(hopSec*fs));
      starts = 1:H:max(1, T-F+1);
      plan.starts = starts(:);
      plan.counts = repmat(F, numel(starts), 1);
    end

    function validateAgainstGraph(Nsig, Ngraph)
    % Basic N (channel/node) consistency check.
      assert(Nsig==Ngraph, 'bct:signal:NodeMismatch: %d vs %d', Nsig, Ngraph);
    end
  end
end
