function run_cwt_to_bct_demo()
% End-to-end: create BCT -> write graph & raw -> CWT -> store TF -> bandpass read

%% 0) Setup
bioctree_init();                        % make sure toolbox is on MATLAB path
outfn = 'sub-01_cwt_demo.bct.h5';       % stored under <repo>/data/bioctree_files/raw/...
B = bct.bct.create(outfn);              % thanks to Paths.underData(), this goes under /data

%% 1) Graph (N nodes)
N = 32;
coords = rand(N,3);
E = [randi(N,96,1) randi(N,96,1)];
G = struct('coords',coords,'E',E,'lap_type','normalized','lmax',single(2.0));
B.write_graph(G);

%% 2) Raw default layer (T x N)
fs = 200;                   % Hz
T  = 2000;                  % 10 s
t  = (0:T-1)'/fs;
% synthetic: 10 Hz burst on nodes 1..4, 40 Hz on nodes 5..8, rest noise
X  = 0.1*randn(T,N,'single');
X  = X + sin(2*pi*10*t) .* single((t>2 & t<6)) * [ones(1,4), zeros(1,N-4)];
X(:,5:8) = X(:,5:8) + 0.5*sin(2*pi*40*t);
B.write_raw(X, fs);         % creates /signals/raw and axes; sets default layer id=0

%% 3) CWT per node -> TF cube (F x T x N) -> store as split (real/imag)
% Use cwt with sampling frequency (returns wt: F x T complex, f: F x 1 Hz)
[wt1, f] = cwt(double(X(:,1)), fs);     % double is fine; we cast to single later
F = size(wt1,1);
C = zeros(F, T, N, 'like', single(real(wt1)) + 1i*single(imag(wt1))); % complex single
C(:,:,1) = single(wt1);
for n = 2:N
    wt = cwt(double(X(:,n)), fs);       %#ok<*CWT> size F x T
    C(:,:,n) = single(wt);
end

tf_attrs = struct('transform',"cwt", 'pr_exact',true, 'padding',"reflect", ...
                  'params_json', jsonencode(struct('wavelet','amor')));
B.write_tf_coeffs(reshape(C,[1 F T N]), single(f), tf_attrs);
B.validate();

%% 4) Retrieve an alpha band (8–12 Hz) for default layer, time 2–6 s, nodes 1..12
tspan = [fs*2+1, fs*6];         % samples (inclusive)
nodes = 1:12;

if ismethod(B, 'read_tf_band')
    % Uses default layer automatically if you omit the 5th arg
    Y = B.read_tf_band([8 12], tspan, nodes);   % (L x Tsel x Nsel)
    Y = squeeze(Y);                              % -> (Tsel x Nsel) for L=1
else
    fprintf('[demo] Using inline band reader (naive sum across freq)\n');
    Y = read_tf_band_inline(B.fn, [8 12], tspan, nodes);  % (Tsel x Nsel)
end


%% 5) Quick plots
absY=abs(Y);
figure('Name','Alpha band (8–12 Hz) | default layer'); 
subplot(2,1,1);
imagesc(t(tspan(1):tspan(2)), 1:numel(nodes), absY.'), axis xy
xlabel('Time (s)'); ylabel('Node'); title('Alpha-band reconstructed (naive sum)'); colorbar
subplot(2,1,2);
plot(t, X(:,1), 'k-'); hold on; 
plot(t(tspan(1):tspan(2)), Y(:,1), 'r-');
legend('Raw node 1','Alpha band (node 1)'); grid on
xlabel('Time (s)'); ylabel('Amplitude')

B.validate(); disp('BCT CWT demo complete and validated.');

end

% -------------------------------------------------------------------------
function write_tf_coeffs_inline(h5fn, Cftn, freq_hz)
% Cftn: (F,T,N) complex single (default layer only)
[F,T,N] = size(Cftn);

% Ensure required axes exist
must('/axes/time_s', @() errorIf(~pathExists(h5fn,'/axes/time_s'), 'Missing /axes/time_s'));
must('/axes/node_id', @() errorIf(~pathExists(h5fn,'/axes/node_id'), 'Missing /axes/node_id'));
tAxis = numel(h5read(h5fn,'/axes/time_s')); nAxis = numel(h5read(h5fn,'/axes/node_id'));
errorIf(tAxis~=T || nAxis~=N, 'Axes do not match TF size.');

% freq axis
if ~pathExists(h5fn,'/axes/freq_hz')
    h5create(h5fn,'/axes/freq_hz',[F 1],'Datatype','single');
    h5write(h5fn,'/axes/freq_hz', single(freq_hz(:)));
else
    errorIf(numel(h5read(h5fn,'/axes/freq_hz'))~=F, 'freq_hz length mismatch.');
end

% layer axis (default layer only -> L=1 with id 0). Create if missing.
if ~pathExists(h5fn,'/axes/layer_id')
    h5create(h5fn,'/axes/layer_id',[1 1],'Datatype','int32');
    h5write(h5fn,'/axes/layer_id', int32(0));
end

% datasets (split)
csz = [1 min(F,16) min(T,1024) min(N,128)];
h5create(h5fn,'/decomp/time_freq/coeffs_real',[1 F T N],'Datatype','single', ...
    'ChunkSize', csz, 'Deflate',5, 'Shuffle',true);
h5create(h5fn,'/decomp/time_freq/coeffs_imag',[1 F T N],'Datatype','single', ...
    'ChunkSize', csz, 'Deflate',5, 'Shuffle',true);

h5write(h5fn,'/decomp/time_freq/coeffs_real', real(Cftn), [1 1 1 1], [1 F T N]);
h5write(h5fn,'/decomp/time_freq/coeffs_imag', imag(Cftn), [1 1 1 1], [1 F T N]);

% attach scales
bct.internal.DimScale.attach(h5fn,"/decomp/time_freq/coeffs_real", ...
   {"/axes/layer_id","/axes/freq_hz","/axes/time_s","/axes/node_id"}, ...
   {'layer_id','freq_hz','time_s','node_id'});
bct.internal.DimScale.attach(h5fn,"/decomp/time_freq/coeffs_imag", ...
   {"/axes/layer_id","/axes/freq_hz","/axes/time_s","/axes/node_id"}, ...
   {'layer_id','freq_hz','time_s','node_id'});

% annotate
bct.internal.Util.ensureGroup(h5fn, '/decomp/time_freq');
h5writeatt(h5fn, '/decomp/time_freq', 'tf_complex_storage', 'split');
h5writeatt(h5fn, '/decomp/time_freq', 'transform', 'cwt');
h5writeatt(h5fn, '/decomp/time_freq', 'pr_exact', true);
h5writeatt(h5fn, '/decomp/time_freq', 'padding', 'reflect');
end

function Y = read_tf_band_inline(h5fn, fHz, tSpan, nodes)
freqs = h5read(h5fn,'/axes/freq_hz');
f1 = find(freqs>=fHz(1),1,'first'); f2 = find(freqs<=fHz(2),1,'last');
errorIf(isempty(f1) || isempty(f2) || f1>f2, 'Band not present in freq_hz.');

st = [1 f1 tSpan(1) nodes(1)];
ct = [1 f2-f1+1 tSpan(2)-tSpan(1)+1 nodes(end)-nodes(1)+1];
R  = h5read(h5fn,'/decomp/time_freq/coeffs_real', st, ct);  % (1,F,Tsel,Nsel)
I  = h5read(h5fn,'/decomp/time_freq/coeffs_imag', st, ct);
C  = complex(R,I);
Y  = squeeze(sum(C, 2));   % (Tsel x Nsel) naive synthesis (replace with your inverse)
end

% --- tiny helpers
function errorIf(tf, msg), if tf, error(msg); end, end
function tf = pathExists(fn, path)
try, h5info(fn,path); tf=true; catch, tf=false; end
end
function must(~, fcn), fcn(); end
