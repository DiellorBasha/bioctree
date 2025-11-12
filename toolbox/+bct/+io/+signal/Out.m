classdef Out
% bct.io.signal.Out
% Read/export signals from BCT files by calling @bct readers.

  methods (Static)
    function X = raw(B, tSpan, nodeIdx)
    % Read from /signals/raw (T x N).
      if nargin<2 || isempty(tSpan),  tSpan  = [1 B.T]; end
      if nargin<3 || isempty(nodeIdx),nodeIdx = [1 B.N]; end
      X = B.read_raw(tSpan, nodeIdx);
    end

    function X = stack(B, layers, tSpan, nodeIdx)
    % Read from /signals/raw_stack (Lsel x Tsel x Nsel).
      if nargin<2 || isempty(layers), layers = B.get_default_layer(); end
      if nargin<3 || isempty(tSpan),  tSpan  = [1 B.T]; end
      if nargin<4 || isempty(nodeIdx),nodeIdx= [1 B.N]; end
      X = B.read_raw_layers(layers, tSpan, nodeIdx);
    end

    function Y = tfBand(B, fHz, tSpan, nodeIdx, layers)
    % Reconstruct band-limited signal via @bct.read_tf_band.
      if nargin<5 || isempty(layers), layers = B.get_default_layer(); end
      if nargin<3 || isempty(tSpan),  tSpan  = [1 B.T]; end
      if nargin<4 || isempty(nodeIdx),nodeIdx= [1 B.N]; end
      Y = B.read_tf_band(fHz, tSpan, nodeIdx, layers);
    end
  end
end
