classdef CWT < handle
% bct.filters.CWT — CWT filterbank-based analysis & bandpass reconstruction (B-bound)
% Requires: Wavelet Toolbox
%
% Usage:
%   F = bct.filters.CWT(B, 'Layer', 1);      % build once per layer (default= B.get_default_layer())
%   y = F.bandpass([8 12], 'Nodes', 1:64);   % reconstruct band-limited signal (T×|Nodes|)
%   F.writeTF();                              % optional: persist TF to BCT (split complex)
%
% Notes:
% - This class assumes the BCT file already has /signals/raw with valid T, N, fs.
% - Parallel Toolbox is optional; if available and a pool is open, parfor is used.

    properties (SetAccess=private)
        B                   % bct.bct handle
        layer1  (1,1) double
        fs      (1,1) double
        T       (1,1) double
        N       (1,1) double

        fb                      % cwtfilterbank object
        freq_hz single          % center freqs (F×1), from fb
        params   struct         % bank configuration used (for JSON attr)
    end

    methods
        function obj = CWT(B, varargin)
            % Parse options
            p = inputParser;
            p.addParameter('Layer', [], @(z) isempty(z) || (isscalar(z) && z>=1));
            p.addParameter('VoicesPerOctave', 10, @(x)isscalar(x)&&x>0);
            p.addParameter('Wavelet', 'amor', @(s)ischar(s)||isstring(s));
            p.addParameter('TimeBandwidth', 60, @(x)isscalar(x)&&x>0);
            p.parse(varargin{:});
            opt = p.Results;

            obj.B = B;
            % Resolve layer and cached sizes from B
            obj.T  = B.T; obj.N = B.N; obj.fs = B.fs;
            if isnan(obj.fs) || isnan(obj.T) || isnan(obj.N)
                error('bct:cwt:MissingAxes','B must have /signals/raw with fs, T, N established.');
            end
            if isempty(opt.Layer)
                obj.layer1 = B.get_default_layer();
            else
                obj.layer1 = opt.Layer;
            end

            % Build filterbank ONCE using known T and fs
            obj.fb = cwtfilterbank( ...
                'SignalLength',     obj.T, ...
                'SamplingFrequency',obj.fs, ...
                'VoicesPerOctave',  opt.VoicesPerOctave, ...
                'Wavelet',          opt.Wavelet, ...
                'TimeBandwidth',    opt.TimeBandwidth ...
            );

            % Cache center frequencies (Hz), as single for schema
            obj.freq_hz = single(obj.fb.Frequencies(:));

            % Stash params for attrs (reproducible)
            obj.params = struct('VoicesPerOctave',opt.VoicesPerOctave, ...
                                'Wavelet',char(opt.Wavelet), ...
                                'TimeBandwidth',opt.TimeBandwidth, ...
                                'SignalLength',obj.T, ...
                                'SamplingFrequency',obj.fs);
        end

        function y = bandpass(obj, bandHz, varargin)
            % Reconstruct band-limited signal on the current layer.
            % y: (T × |nodes|)
            %
            % Name-Value:
            %   'Nodes'      : vector of node indices (1-based). Default: 1:N
            %   'TimeSpan'   : [t0 t1] samples (default full 1..T)
            %   'Tag'        : string; if provided, result is cached at /results/bandpass/<tag>/y
            %   'WriteCache' : logical (default false) control write of /results
            p = inputParser;
            p.addParameter('Nodes', 1:obj.N, @(v)isnumeric(v)&&all(v>=1&v<=obj.N));
            p.addParameter('TimeSpan', [1 obj.T], @(v)isnumeric(v)&&numel(v)==2);
            p.addParameter('Tag','',@(s)ischar(s)||isstring(s));
            p.addParameter('WriteCache', false, @(x)islogical(x)||ismember(x,[0 1]));
            p.parse(varargin{:});
            opt = p.Results;

            nodes = opt.Nodes(:)';
            t0 = opt.TimeSpan(1); t1 = opt.TimeSpan(2);
            if t0<1 || t1>obj.T || t0>t1, error('bct:cwt:BadTimeSpan','Invalid TimeSpan.'); end

            % Read the layer slice once (T×|nodes|)
            X = obj.B.read_raw([t0 t1], nodes, obj.layer1);
            % Preallocate output
            y = zeros(size(X), 'single');

            % Precompute freq mask indices from fb.Frequencies
            f = double(obj.freq_hz);
            f1 = find(f >= bandHz(1), 1, 'first');
            f2 = find(f <= bandHz(2), 1, 'last');
            if isempty(f1) || isempty(f2) || f1>f2
                error('bct:cwt:BandNotCovered','Band [%g %g] Hz not covered by filterbank.', bandHz(1), bandHz(2));
            end

            % Loop nodes (parfor if pool exists)
            parfor (k = 1:numel(nodes), bct.filters.CWT.recommendedPool())
                x = double(X(:,k));                      % cwt expects double
                wt = cwt(x, 'FilterBank', obj.fb);      % F × T (complex double)
                % Zero outside band to reduce icwt work (optional)
                wt(1:f1-1,:)  = 0;
                wt(f2+1:end,:)= 0;
                % Inverse CWT (analytic wavelets → PR within limits)
                yk = icwt(wt, 'FilterBank', obj.fb, 'FrequencyLimits', bandHz);
                y(:,k) = single(real(yk));              % real-valued signal
            end

            % Optional: write cache at /results/bandpass/<tag>/y
            if ~isempty(opt.Tag) && opt.WriteCache
                obj.writeBandResult(y, opt.Tag, nodes, [t0 t1]);
            end
        end

        function writeTF(obj, varargin)
            % Compute TF for all nodes of the current layer and persist via B.write_tf_coeffs
            % Name-Value:
            %   'Nodes' : default 1:N
            %   'Attrs' : struct for TF attrs (transform, padding, etc.)
            p = inputParser;
            p.addParameter('Nodes', 1:obj.N, @(v)isnumeric(v)&&all(v>=1&v<=obj.N));
            p.addParameter('Attrs', struct(), @(s)isstruct(s));
            p.parse(varargin{:});
            opt = p.Results;

            nodes = opt.Nodes(:)';
            F = numel(obj.freq_hz);
            Tsel = obj.T; Nsel = numel(nodes);

            % Preallocate complex single TF: (L=1, F, T, Nsel)
            C = complex(zeros(1,F,Tsel,Nsel,'single'));

            % Compute per-node TF
            parfor (k = 1:Nsel, bct.filters.CWT.recommendedPool())
                x = double(obj.B.read_raw([1 obj.T], nodes(k), obj.layer1));
                wt = cwt(x, 'FilterBank', obj.fb);    % F×T
                C(1,:,:,k) = single(wt);
            end

            % TF attrs (enforced + params_json)
            attrs = struct('transform',"cwt", ...
                           'pr_exact', true, ...
                           'padding',  "none", ...
                           'params_json', jsonencode(obj.params));
            % Merge user fields
            fn = fieldnames(opt.Attrs);
            for i=1:numel(fn), attrs.(fn{i}) = opt.Attrs.(fn{i}); end

            % Persist
            obj.B.write_tf_coeffs(C, obj.freq_hz, attrs);
        end
    end

    methods (Access=private)
        function writeBandResult(obj, y, tag, nodes, tSpan)
            % /results/bandpass/<tag>/y  with shape single(L,T_sel,N_sel); L=1 here
            base = "/results/bandpass/" + string(tag);
            dset = base + "/y";
            % Ensure group
            bct.internal.Util.ensureGroup(obj.B.fn, char(base));

            Tsel = size(y,1); Nsel = size(y,2);
            % Create or validate dataset
            if ~bct.internal.Util.pathExists(obj.B.fn, dset)
                h5create(obj.B.fn, char(dset), [1 Tsel Nsel], 'Datatype','single', ...
                    'ChunkSize', [1 min(Tsel,1024) min(Nsel,128)], 'Deflate',5, 'Shuffle',true);
            else
                s = h5info(obj.B.fn, char(dset));
                assert(all(s.Dataspace.Size == [1 Tsel Nsel]), 'bct:ResultShapeMismatch', ...
                    'Existing cache size differs from current selection.');
            end

            h5write(obj.B.fn, char(dset), y, [1 1 1], [1 Tsel Nsel]);
            % Annotate selection metadata
            meta = struct('layer', obj.layer1, 'band_hz', tag, 'nodes', nodes, 'tSpan', tSpan);
            bct.internal.Attr.write(obj.B.fn, char(base), 'selection_json', jsonencode(meta));
            bct.internal.Attr.write(obj.B.fn, char(base), 'datatype', 'bandpass');
        end
    end

    methods (Static, Access=private)
        function n = recommendedPool()
            if license('test','Distrib_Computing_Toolbox') && ~isempty(gcp('nocreate'))
                n = Inf;        % use pool
            else
                n = 0;          % run serially
            end
        end
    end
end
