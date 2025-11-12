bstdb='/export02/export01/data/dbasha/code/brainstorm-compiled/brainstorm_db/TutorialOmega/data/';
addpath('/export01/data/dbasha/code/brainstorm/brainstorm3/')
addpath('/export02/export01/data/dbasha/code/bioctree')
%% 
addpath('C:\CodingProjects\brainstorm3\')
addpath('C:\CodingProjects\bioctree\');
bstdb='Z:\brainstorm_protocols\TutorialOmega\data'
bstdbanat='Z:\brainstorm_protocols\TutorialOmega\anat'

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

prot(k).Study=sStudy;
prot(k).Subject=sSubject;
prot(k).SensorMetadata = sFilesIn(k).Data;
prot(k).SensorData = load(fullfile(bstdb,sFilesIn(k).Data.FileName));
prot(k).ImagingKernel = load(fullfile(bstdb,prot(k).Study.Result.FileName));
prot(k).Surface = load(fullfile(bstdbanat, ikernel.SurfaceFile));
prot(k).chans=prot(k).ImagingKernel.GoodChannel;
end
% 
%% 



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
%% 
fs = 3000;
t = 0:1/fs:3-1/fs;
data = {chirp(t,300,t(end),800).*exp(2j*pi*10*cos(2*pi*2*t)); ...
        2*chirp(t,200,t(end),1000,'quadratic',[],'concave'); ...
        vco(sin(2*pi*t),[0.1 0.4]*fs,fs)};
sds = signalDatastore(data,'SampleRate',fs);


addpath('C:\CodingProjects\brainstorm3\')
addpath('C:\CodingProjects\bioctree\');
bstdb='Z:\brainstorm_protocols\TutorialOmega\data';
bstdbanat='Z:\brainstorm_protocols\TutorialOmega\anat';
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

prot(k).Study=sStudy;
prot(k).Subject=sSubject;
prot(k).SensorMetadata = sFilesIn(k).Data;
prot(k).SensorData = load(fullfile(bstdb,sFilesIn(k).Data.FileName));
prot(k).ImagingKernel = load(fullfile(bstdb,prot(k).Study.Result.FileName));
prot(k).Surface = load(fullfile(bstdbanat, ikernel.SurfaceFile));
prot(k).chans=prot(k).ImagingKernel.GoodChannel;
end
%% === Load source & infer sampling rate ===================================
d   = load("test-data/sFiles.mat");

for k = 1:length(idx)
 thisidx =idx(k)
fn=p.ProtocolStudies.Study(thisidx).Data.FileName;
[sStudy, iStudy, iData] = bst_get('DataFile', fn);
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
prot(k).Study=sStudy;
prot(k).Subject=sSubject;
prot(k).SensorMetadata = d.sFilesIn(k).Data;
prot(k).SensorData = load(fullfile(bstdb,d.sFilesIn(k).Data.FileName));
prot(k).ImagingKernel = load(fullfile(bstdb,prot(k).Study.Result.FileName));
prot(k).Surface = load(fullfile(bstdbanat, prot(k).ImagingKernel.SurfaceFile));
prot(k).chans=prot(k).ImagingKernel.GoodChannel;
end
%% 
d   = load("test-data/sFiles.mat");
sIn = load(d.files{1});                      % sIn.F [nChan x nSamp], sIn.Time [1 x nSamp]
sF=sIn.F(prot(1).chans, :);
sIk = prot(1).ImagingKernel.ImagingKernel;
sSurf = prot(1).Surface;
dt  = diff(sIn.Time(1:2));
fs  = 1/dt;
chanFile = load(fullfile(bstdb,prot(1).SensorMetadata.ChannelFile));
chanNames=string({chanFile.Channel.Name});
chanNames=chanNames(prot(1).chans)
% Ensure uniform time spacing (optional but recommended)
tol = 1e-9;
assert(all(abs(diff(sIn.Time) - dt) < tol), 'Time axis is not strictly uniform.');

[nChan, nSamp] = size(sF);
fprintf('fs = %.6f Hz | nChan=%d | nSamp=%d\n', fs, nChan, nSamp);


%% === Channel names (as string column) ===================================
assert(numel(chanNames) == nChan, 'chanNames length must equal number of channels.');

% Sanitize for HDF5 dataset-friendly names if needed later
sanNames = regexprep(chanNames, '[^\w\-]+', '_');
sanNames = strip(sanNames, '_');

%% === Write ONE HDF5 with all channels (time×channels) ===================
frameSec    = 4;                               % EXACT 4-second chunks
frameSamps  = round(frameSec * fs);            % e.g., 1200 @ 300 Hz
Cchunk      = 1;                                % 1 column per chunk (optimize per-channel reads)
chunkSize   = [frameSamps, Cchunk];

src = d.sFilesIn(1).Data;
% Split on either / or \ and take the 2nd component if it exists
outFile = fullfile(pwd, 'data', 'bioctree_files','raw', src.SubjectName + ".h5");                    % -> sub-0002_ses-01_task-rest_run-01_meg_notch_high.h5
fprintf('Output HDF5: %s\n', outFile);

if isfile(outFile), delete(outFile); end
fprintf('Writing %s with chunk = [%d × %d] (%.3f s × %d ch)\n', ...
        outFile, chunkSize(1), chunkSize(2), frameSamps/fs, Cchunk);

% Tiny dataset to attach root attributes
h5create(outFile, '/.init', [1 1], 'Datatype', 'uint8');
h5write(outFile, '/.init', uint8(0));

% 1) Simple root attributes
h5writeatt(outFile, '/', 'SourceFileName', src.FileName);
h5writeatt(outFile, '/', 'SourceFileType', src.FileType);
h5writeatt(outFile, '/', 'SourceComment',  src.Comment);
h5writeatt(outFile, '/', 'Condition',      src.Condition);
h5writeatt(outFile, '/', 'SubjectFile',    src.SubjectFile);
h5writeatt(outFile, '/', 'SubjectName',    src.SubjectName);
h5writeatt(outFile, '/', 'ChannelFile',    src.ChannelFile);
h5writeatt(outFile, '/', 'iStudy',         int32(src.iStudy));
h5writeatt(outFile, '/', 'iItem',          int32(src.iItem));
% Root attributes
h5writeatt(outFile, '/', 'CreationDate', string(datetime('now')));
h5writeatt(outFile, '/', 'SampleRateHz', fs);
h5writeatt(outFile, '/', 'NumChannels',  nChan);
h5writeatt(outFile, '/', 'NumSamples',   nSamp);
if isfield(sIn,'Comment'), h5writeatt(outFile, '/', 'Comment', sIn.Comment); end
if isfield(sIn,'Device'),  h5writeatt(outFile, '/', 'Device',  sIn.Device);  end

% 2) Lists (cellstr works best for variable-length string attributes)
if isfield(src,'ChannelTypes') && ~isempty(src.ChannelTypes)
    h5writeatt(outFile, '/', 'ChannelTypes', cellstr(src.ChannelTypes));
end

% 3) Full original struct as JSON (preserves everything)
originJSON = jsonencode(src);                    % char row vector
h5writeatt(outFile, '/', 'OriginJSON', originJSON);

% (Optional) Who/when
h5writeatt(outFile, '/', 'WrittenBy', getenv("USERNAME"));
h5writeatt(outFile, '/', 'WriteTimestamp', char(string(datetime('now'))));

% Main signal dataset: [nSamp × nChan]
Ftc = single(sF.');                          % transpose to time-major
h5create(outFile, '/signals/F', size(Ftc), ...
    'Datatype', 'single', 'ChunkSize', chunkSize, 'Deflate', 3);
h5write(outFile, '/signals/F', Ftc);

% Channel names dataset (fixed-width char array for portability)
% Channel names as a root attribute (portable + simple)
names = cellstr(string(chanNames(:)));        % cellstr required by h5writeatt
h5writeatt(outFile, '/', 'ChannelNames', names);

fprintf('HDF5 written.\n');


%% === Use the datastore (save class below as H5ChannelDatastore.m) ========
outFile=fullfile(pwd, 'data', 'bioctree_files','raw', "sub-0002" + ".h5");     
ds = H5ChannelDatastore(outFile);
% Quick sanity check
hasdata(ds)
[TT, info] = read(ds);      % TT: timetable with variable 'x', Time in seconds
disp(info)
head(TT)
reset(ds)
%% 
[TT, info] = read(ds);        % TT: timetable with var 'x', time in seconds
[TTp, newFs] = preprocessTT(TT);
nSampNew = height(TTp);
nChan    = ds.NumChannels;
% Choose chunking aligned to your framing (still 4 s windows)
frameSec    = 4;
frameSampsP = round(frameSec * newFs);
chunkSize   = [frameSampsP 1];

% Create /preproc/F as [nSampNew x nChan], time-major (rows=time, cols=channels)
if isfile(outFile)  % (file exists by definition)
    if ~isempty(h5info(outFile,'/')) %#ok<*H5I>
        % ok
    end
end
% Create the dataset (will auto-create /preproc group)
if any(strcmp({h5info(outFile,'/').Groups.Name}, '/preproc'))
    % If re-running, delete existing dataset (MATLAB can't overwrite)
    % (If you want versioning, write to /preproc/v1, /preproc/v2, etc. instead)
end
h5create(outFile, '/preproc/F', [nSampNew nChan], ...
    'Datatype','single', 'ChunkSize', chunkSize, 'Deflate', 3);
% Channel names attribute for /preproc (copy from root)
try
    nm = h5readatt(outFile, '/', 'ChannelNames');
catch
    nm = cellstr(string("chan_"+compose("%03d",1:nChan)));
end
h5writeatt(outFile, '/preproc', 'ChannelNames', nm);
h5writeatt(outFile, '/preproc', 'SampleRateHz', newFs);

% Write the first channel column
varName = TTp.Properties.VariableNames{1};
y = single(TTp.(varName));
h5write(outFile, '/preproc/F', y, [1 1], [nSampNew 1]);

% Loop remaining channels
k = 2;
while hasdata(ds)
    TT   = read(ds);                 % next channel
    TTp  = preprocessTT(TT);             % returns timetable w/ same var name
    y    = single(TTp.(TTp.Properties.VariableNames{1}));

    % Safety: ensure same length after preprocessing
    if height(TTp) ~= nSampNew
        error('Preprocessed length mismatch on channel %d (got %d, expected %d).', ...
              k, height(TTp), nSampNew);
    end

    h5write(outFile, '/preproc/F', y, [1 k], [nSampNew 1]);
    k = k + 1;
end