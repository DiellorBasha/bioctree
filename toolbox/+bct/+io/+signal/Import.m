classdef Import
  % bct.io.signal.Import
  % High-level signal import pipeline
  
  methods (Static)
    function B = fromFreeSurfer(path, B_existing)
      % Import FreeSurfer curvature file into BCT object
      % 
      % Usage:
      %   B = bct.io.signal.Import.fromFreeSurfer(path)           % Create new BCT
      %   B = bct.io.signal.Import.fromFreeSurfer(path, B_existing) % Add to existing
      %
      % Parameters:
      %   path - Path to FreeSurfer .curv file
      %   B_existing - (optional) Existing BCT object to add signal to
      %
      % Returns:
      %   B - BCT object with imported signal in signal stack
      
      if nargin < 2 || isempty(B_existing)
        % Create new BCT object
        B = bct.bct();
        B.fn = "";  % In-memory object
      else
        B = B_existing;
      end
      
      % Read FreeSurfer curv file
      raw = bct.io.signal.In.readFreeSurferCurv(path);
      
      % Convert to signal snapshot
      snap = bct.io.signal.Convert.freeSurferCurvToSnapshot(raw);
      
      % Create metadata structure
      metadata = struct();
      metadata.source_file = snap.source_file;
      metadata.file_type = snap.file_type;
      metadata.data_type = snap.data_type;
      metadata.hemisphere = snap.hemisphere;
      metadata.signal_type = snap.signal_type;
      metadata.import_date = datestr(now, 'yyyy-mm-dd HH:MM:SS');
      metadata.vertices_count = snap.N;
      
      % Add signal to BCT object
      B.addSignal(snap.signal, snap.label, metadata);
      
      % Update N if not set
      if isnan(B.N) || B.N == 0
        B.N = snap.N;
      end
    end
    
    function B = fromFile(path, B_existing)
      % Auto-detect file type and import
      %
      % Parameters:
      %   path - Path to signal file
      %   B_existing - (optional) Existing BCT object
      %
      % Returns:
      %   B - BCT object with imported signal
      
      if nargin < 2
        B_existing = [];
      end
      
      if bct.io.signal.Convert.looksLikeFreeSurferCurv(path)
        B = bct.io.signal.Import.fromFreeSurfer(path, B_existing);
      elseif bct.io.signal.Convert.looksLikeBrainstorm(path)
        error('bct:io:NotImplemented', 'Brainstorm signal import not implemented yet');
      else
        error('bct:io:UnknownFormat', 'Cannot infer signal format from: %s', string(path));
      end
    end
    
    % Convenience aliases
    function B = FreeSurfer(path, varargin)
      B = bct.io.signal.Import.fromFreeSurfer(path, varargin{:});
    end
  end
end