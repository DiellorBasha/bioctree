classdef In
% bct.io.signal.In
% Ingest signals into BCT files by calling @bct writers.

  methods (Static)
    function raw(B, X, fs)
    % Write /signals/raw (and axes if needed).
      S = bct.io.signal.Construct.normalizeRaw(X, fs);
      if ~isnan(B.N) && B.N>0
        bct.io.signal.Construct.validateAgainstGraph(S.N, B.N);
      end
      B.write_raw(S.X, S.fs);
    end

    function stack(B, Xltn, fs, layer_ids)
    % Write /signals/raw_stack (L x T x N) with /axes/layer_id.
      S = bct.io.signal.Construct.normalizeStack(Xltn, fs, layer_ids);
      if ~isnan(B.N) && B.N>0
        bct.io.signal.Construct.validateAgainstGraph(S.N, B.N);
      end
      B.write_raw_layers(S.Xltn, S.fs, S.layer_ids);
    end

    function tf(B, C, freq_hz, attrs)
    % Write TF coefficients; C is (F x T x N) or (L x F x T x N).
      if ndims(C)==3 || ndims(C)==4
        B.write_tf_coeffs(C, freq_hz, attrs);
      else
        error('C must be 3D or 4D.');
      end
    end

    function fromBrainstorm(B, matFile)
    % Convenience loader: Brainstorm → /signals/raw
      snap = bct.io.signal.Convert.fromBrainstormRaw(matFile);
      bct.io.signal.In.raw(B, snap.X, snap.fs);
    end
    
    function readFreeSurferCurv(path)
    % Read FreeSurfer curvature file
    % Returns struct with curv data and metadata
      
      % Open file as big-endian
      fid = fopen(path, 'rb', 'b');
      if fid < 0
        error('bct:io:CannotOpenFile', 'Could not open file: %s', path);
      end
      
      try
        % Read magic number to determine version
        vnum = bct.io.signal.In.fs_fread3(fid);
        NEW_VERSION_MAGIC_NUMBER = 16777215;
        
        if vnum == NEW_VERSION_MAGIC_NUMBER
          % New version (float format)
          vnum = fread(fid, 1, 'int32');
          fnum = fread(fid, 1, 'int32');
          vals_per_vertex = fread(fid, 1, 'int32'); %#ok<NASGU>
          curv = fread(fid, vnum, 'float');
          data_type = 'float32';
        else
          % Old version (int16 format)
          fnum = bct.io.signal.In.fs_fread3(fid);
          curv = fread(fid, vnum, 'int16') ./ 100;
          data_type = 'int16_scaled';
        end
        
        fclose(fid);
        
        % Create return structure
        raw = struct();
        raw.curv = curv;
        raw.vnum = vnum;
        raw.fnum = fnum;
        raw.data_type = data_type;
        raw.source_file = path;
        raw.file_type = 'freesurfer_curv';
        
      catch ME
        fclose(fid);
        rethrow(ME);
      end
    end
  end
  
  methods (Static, Access=private)
    function val = fs_fread3(fid)
    % Read 3-byte integer (FreeSurfer format)
      b1 = fread(fid, 1, 'uchar');
      b2 = fread(fid, 1, 'uchar'); 
      b3 = fread(fid, 1, 'uchar');
      val = bitshift(b1, 16) + bitshift(b2, 8) + b3;
    end
  end
end
