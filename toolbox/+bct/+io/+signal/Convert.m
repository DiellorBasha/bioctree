classdef Convert
% bct.io.signal.Convert
% Adapters to/from external signal ecosystems (stubs you can flesh out).

  methods (Static)
    function snap = fromBrainstormRaw(matFile)
    % Load Brainstorm-like raw; adjust field names to your data.
      S = load(matFile);
      if isfield(S,'F')
        X = S.F;                 % (T x N) or (N x T) — transpose if needed
        if size(X,1) < size(X,2), X = X.'; end
      else
        error('Expected field F in Brainstorm .mat');
      end
      if isfield(S,'sfreq')
        fs = double(S.sfreq);
      elseif isfield(S,'Time')
        fs = 1/mean(diff(S.Time));
      else
        error('Cannot infer fs from Brainstorm file.');
      end
      snap = struct('X',X,'fs',fs, ...
        'meta',struct('source','brainstorm','file',matFile));
    end

    function tf = looksLikeBrainstorm(path)
      tf = endsWith(string(path), ".mat");
    end
    
    function tf = looksLikeFreeSurferCurv(path)
      % Check if path looks like FreeSurfer curvature file
      path_str = string(path);
      tf = endsWith(path_str, ".curv") || ...
           contains(path_str, ".curv") || ...
           contains(path_str, "curv");
    end
    
    function snap = freeSurferCurvToSnapshot(raw)
      % Convert FreeSurfer curv raw data to signal snapshot
      
      if ~isfield(raw, 'curv') || ~isfield(raw, 'source_file')
        error('bct:io:InvalidCurvData', 'Invalid FreeSurfer curv data structure');
      end
      
      % Extract filename for labeling
      [~, fname, ext] = fileparts(raw.source_file);
      
      % Create snapshot structure
      snap = struct();
      snap.signal = raw.curv(:);  % Ensure column vector
      snap.N = length(raw.curv);
      snap.label = sprintf('%s%s', fname, ext);
      snap.data_type = raw.data_type;
      snap.source_file = raw.source_file;
      snap.file_type = 'freesurfer_curv';
      
      % Add hemisphere information if detectable from filename
      if contains(fname, '_lh') || contains(fname, 'lh.')
        snap.hemisphere = 'left';
      elseif contains(fname, '_rh') || contains(fname, 'rh.')
        snap.hemisphere = 'right';
      else
        snap.hemisphere = 'unknown';
      end
      
      % Add signal type based on common FreeSurfer names
      if contains(fname, 'curv')
        snap.signal_type = 'curvature';
      elseif contains(fname, 'sulc')
        snap.signal_type = 'sulcal_depth';
      elseif contains(fname, 'thick')
        snap.signal_type = 'thickness';
      elseif contains(fname, 'area')
        snap.signal_type = 'surface_area';
      else
        snap.signal_type = 'unknown';
      end
    end

    function ft = toFieldTripStruct(B, tSpan, nodeIdx)
    % Example export (very basic, one continuous trial).
      if nargin<2 || isempty(tSpan),  tSpan  = [1 B.T]; end
      if nargin<3 || isempty(nodeIdx),nodeIdx = [1 B.N]; end
      X = B.read_raw(tSpan, nodeIdx);    % (T x N)
      ft = struct();
      ft.label   = arrayfun(@(k) sprintf('ch%d',k-1), nodeIdx(:), 'uni', 0);
      ft.fsample = B.fs;
      ft.trial   = {X.'};                % (N x T)
      ft.time    = {(0:size(X,1)-1)/B.fs};
    end
  end
end
