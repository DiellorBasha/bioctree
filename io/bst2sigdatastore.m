bstdb='/export02/export01/data/dbasha/code/brainstorm-compiled/brainstorm_db/TutorialOmega/data/';
addpath('/export01/data/dbasha/code/brainstorm/brainstorm3/')
addpath('/export02/export01/data/dbasha/code/bioctree')
bioctree_start
brainstorm nogui
fds = fileDatastore(bstdb,"ReadFcn",@load,"FileExtensions",".mat");
p = read(fds);
names = string({p.ProtocolStudies.Study.Name});
fnames = string({p.ProtocolStudies.Study.FileName});
keepMask = startsWith(names, "@raw") & ~contains(names, "emptyroom", 'IgnoreCase', true);
rawNames = names(keepMask);
rawPaths = fnames(keepMask);   % the matches
idx      = find(keepMask);    % their indices (into the flattened Study list)
%%
% Import in database and downsample
for k = 1:length(idx)
 thisidx =idx(k)
fn=p.ProtocolStudies.Study(thisidx).Data.FileName;
[sStudy, iStudy, iData] = bst_get('DataFile', fn);
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
sFiles{k}=fn;
SubjectNames{k}=sSubject.Name;
% Process: Import MEG/EEG: Time
sFilesIn(k).Data = bst_process('CallProcess', 'process_import_data_time', sFiles{k}, [], ...
    'subjectname',   SubjectNames{k}, ...
    'condition',     '', ...
    'timewindow',    [], ...
    'split',         0, ...
    'ignoreshort',   1, ...
    'usectfcomp',    1, ...
    'usessp',        1, ...
    'freq',          300, ...
    'baseline',      [], ...
    'blsensortypes', 'MEG, EEG');
end
% 

%%
files = arrayfun(@(s) fullfile(bstdb, s.Data.FileName), sFilesIn, ...
                 'UniformOutput', false);
files = unique(files);   % just in case there are duplicates
%% 
% files : cellstr of absolute paths (you already built this)
outSuffix = '';              % '' to overwrite in place, or e.g. '.v73' to write side-by-side
for i = 1:numel(files)
    in  = files{i};
    [p,n,e] = fileparts(in);
    out = fullfile(p, [n outSuffix e]);
    fprintf('Converting to -v7.3: %s\n', in);
    % Load everything (or list specific variables to reduce peak RAM)
    S = load(in);
    % Optional: drop unneeded bulky fields before saving
    % S.SomeHugeThing = [];  % if not needed
    % Save as v7.3 (HDF5 / chunked). Use '-nocompression' for faster I/O if disk space is OK.
    save(out, '-struct', 'S', '-v7.3');           % or: save(out,'-struct','S','-v7.3','-nocompression')
    % Optional: verify that partial loading works now
    m = matfile(out);
    szF = size(m, 'F'); 
end
%% 

opts = struct( ...
    'channels',   [],        ... % [] = all channels, or e.g., 1:128
    'cast',       'single',  ... % 'single' (GPU-friendly) or 'double'
    'useMatfile', true);
% 3) Make the datastore (pass options via anonymous function)
fds = fileDatastore(files, ...
    'ReadFcn',        @load, ...
    'FileExtensions', '.mat', ...
    'IncludeSubfolders', false);
preview(fds)
%% 
sds = signalDatastore(files, ...
    'ReadFcn', @read_bs_tt, ...
    'FileExtensions', '.mat', ...
    'IncludeSubfolders', false);

preview(sds)   % shows a timetable with ch001..ch300, SampleRate set

%%
% Config for CWT
flim = [0.5 60];
vpo  = 12;

reset(sds);
while hasdata(sds)
    TT = read(sds);                        % timetable T×Ch
    Fs = TT.Properties.SampleRate;
    T  = height(TT);
    X  = TT.Variables;                     % numeric [T x Ch], single

    % Reusable filter bank for FULL time
    fb = cwtfilterbank(SamplingFrequency=Fs, ...
                       FrequencyLimits=flim, ...
                       VoicesPerOctave=vpo, ...
                       SignalLength=T);

    % Frequency axis
    [~, fvec] = wt(fb, X(1,:).');         % (F x T) for one channel; get F
    F = numel(fvec);

    % Decide channel batch from free VRAM
    g = gpuDevice;
    safety = 0.70;
    avail  = g.AvailableMemory * safety;  % bytes
    bytesPerChan = F*T*4;                 % power (real single)
    eff = 2*bytesPerChan;                 % crude temp factor
    batch = max(1, floor(avail/eff));
    batch = min(batch, size(X,2));

    % Preallocate a GPU slab [F x T x batch] (power recommended)
    Pg = gpuArray.zeros(F, T, batch, 'single');

    % Destination on CPU for this file, if you want to keep it
    P = zeros(F, T, size(X,2), 'single');

    % Loop over channel batches (no time windowing)
    for sIdx = 1:batch:size(X,2)
        k = sIdx:min(sIdx+batch-1, size(X,2));
        Xg = gpuArray(X(:,k));            % [T x batch]
        for i = 1:numel(k)
            % wt expects row vector; transpose one channel at a time
            Cg = wt(fb, Xg(:,i).');       % [F x T] complex gpuArray
            Pg(:,:,i) = abs(Cg).^2;       % store power (real single)
        end
        P(:,:,k) = gather(Pg(:,:,1:numel(k)));
    end

    % Example: do something with P here (save, summarize, etc.)
    % save('cwt_<file>.mat','P','fvec','-v7.3');

end

%% CWT on GPU for multi-channel data (R2025b+)
% Data: dblock1.F is 300 x 30000 (channels x time), Fs = 300 Hz
% Bands: 0.5–60 Hz, 12 voices/octave

X = single(dblock.F);                             % 300 x 30000
Fs   = 1/diff(dblock.Time(1:2));
flim = [0.5 60];
vpo  = 12;
[Ch, T] = size(X);
TimeSec=dblock.Time;
storeMode = "complex";          % "power" (real single, recommended) or "complex"

fprintf('MATLAB %s | GPU(s)=%d | Data: %d ch x %d samples @ %.1f Hz\n', ...
        version, gpuDeviceCount, Ch, T, Fs);

%% Build ONE reusable filter bank over FULL time
fb = cwtfilterbank( ...
    SamplingFrequency = Fs, ...
    FrequencyLimits   = flim, ...
    VoicesPerOctave   = vpo, ...
    SignalLength      = T);

% Metadata/helpers (object functions)
FreqHz  = centerFrequencies(fb);     % [F x 1]
Scales  = scales(fb);                % [F x 1]
Q       = qfactor(fb);
BW3dB   = powerbw(fb);
WavSupp = waveletsupport(fb);

% Exact F from a tiny dry run
tmpC = wt(fb, X(1,:));               % [F x T] (complex, CPU)
F = size(tmpC,1);
clear tmpC
fprintf('Filter bank: F=%d frequencies, T=%d time samples\n', F, T);

%% Preallocate destination on CPU (choose storage)
switch string(storeMode)
    case "power"
        C = zeros(F, T, Ch, 'single');               % [F x T x Ch], real single
        bytesPerChan = F*T*4;
        toSlab = @(Cg) single(abs(Cg).^2);
    case "complex"
        C = complex(zeros(F, T, Ch, 'single'));      % [F x T x Ch], complex single
        bytesPerChan = F*T*8;
        toSlab = @(Cg) single(Cg);
    otherwise
        error('storeMode must be "power" or "complex".');
end

%% Choose a safe channel BATCH from available VRAM
g = gpuDevice;
safety = 0.70;                          % use ~70% of free memory
avail  = g.AvailableMemory * safety;

% crude workspace factor (~2x per channel for intermediates)
bytesPerChanEff = 2 * bytesPerChan;
batch = max(1, floor(avail / bytesPerChanEff));
batch = min(batch, Ch);
fprintf('GPU: %s | Free ~%.1f GB | batch=%d (store=%s)\n', ...
        g.Name, g.AvailableMemory/2^30, batch, storeMode);

%% Preallocate one GPU slab [F x T x batch]
switch string(storeMode)
    case "power"
        slab = gpuArray.zeros(F, T, batch, 'single');             % real single
    case "complex"
        slab = complex(gpuArray.zeros(F, T, batch, 'single'));    % complex single
end

%% Compute: full-time CWT via fb.wt, batching over channels only
tAll = tic;
for s = 1:batch:Ch
    k = s : min(s+batch-1, Ch);

    % Upload the entire time series for this batch
    Xg = gpuArray(X(k, :));                           % [batch x T]

    % Fill the slab planes with full-time CWT for each channel
    for i = 1:numel(k)
        Cg = wt(fb, Xg(i,:));                         % [F x T] complex gpuArray
        slab(:,:,i) = toSlab(Cg);                     % power or complex(single)
    end

    % Copy slab back into the CPU volume
    C(:,:,k) = gather(slab(:,:,1:numel(k)));
end
t = toc(tAll);
fprintf('CWT done in %.2f s (%.3f s/channel)\n', t, t/Ch);

%% Channel-wise summaries via object functions (full time; on CPU)
TSpec = zeros(F, Ch, 'single');   % time-averaged spectrum (power)
SSpec = zeros(T, Ch, 'single');   % scale-averaged spectrum (power)

for k = 1:Ch
  chmag=abs(C(:,:,k));
  tspec = mean(chmag, 2);
  sspec = mean(chmag,1);
    TSpec(:,k) = single(tspec);  % [F x 1]
    SSpec(:,k) = (single(sspec)); % [F x 1]
end

%alpha
idx=FreqHz>7&FreqHz<13;
alphaFreqs=FreqHz(idx)
alphaF=length(alphaFreqs)
TSpecAlpha = zeros(alphaF, Ch, 'single');   % time-averaged spectrum (power)
SSpecAlpha = zeros(T, Ch, 'single');   % scale-averaged spectrum (power)

for k = 1:Ch
  chmag=abs(C(idx,:,k));
  tspec = mean(chmag, 2);
  sspec = mean(chmag,1);
    TSpecAlpha(:,k) = single(tspec);  % [F x 1]
    SSpecAlpha(:,k) = (single(sspec)); % [F x 1]
end
%% 

figure(1)
subplot (211)
plot(FreqHz, mean(TSpec(:,dspm.GoodChannel),2), 'k')
subplot(212)
plot(TimeSec, mean(SSpec(:,dspm.GoodChannel),2), 'k')

%%
chplot=100
figure(2)
ax=subplot (211)
imagesc(TimeSec, FreqHz, squeeze(abs(C(:,:,chplot)))); axis xy tight
ax2=subplot(212)
plot(TimeSec, mean(SSpecAlpha(:,chplot),2), 'k')
linkaxes([ax, ax2], 'x')

%% 
almean=mean(SSpecAlpha(:,chplot),2);
timeSpectrum(fb,almean)
cwt(almean, Filterbank=fb)
%% Quick peek (Channel 1)
ch = 250;
figure; imagesc(TimeSec, FreqHz, squeeze(abs(C(:,:,ch)))); axis xy tight
xlabel('Time (s)'); ylabel('Frequency (Hz)'); colorbar
title(sprintf('CWT %s — Channel %d', upper(string(storeMode)), ch));

%% Export (optional)
out.FreqHz  = FreqHz(:);
out.TimeSec = TimeSec(:).';
out.C       = C;          % [F x T x Ch], single (power or complex)
out.TSpec   = TSpec;      % [F x Ch]
out.SSpec   = SSpec;      % [F x Ch]
out.meta = struct('Scales',Scales,'QFactor',Q,'BW3dB',BW3dB, ...
                  'WaveletSupport',WavSupp,'Fs',Fs,'Flim',flim,'VPO',vpo);
% save('cwt_fulltime_gpu.mat','-struct','out','-v7.3');
