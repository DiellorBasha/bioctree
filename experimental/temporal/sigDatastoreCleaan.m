addpath("toolbox")
bct.start
addpath("external/brainstorm3")
addpath("external/bioelectromagnetism/")

%%
clear
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
% Subject to analyze
subjectId = "sub-0007";
subjectPath  = fullfile(analysisRoot, subjectId);

meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
sfreq = meta.sfreq;
cwtPath  = fullfile(subjectPath, "cwt");
cwtFileSet = matlab.io.datastore.DsFileSet(fullfile(cwtPath, "data"));
cwtStore = signalDatastore(cwtFileSet, "SampleRate",sfreq);

nBands = 5; 
    % Read all channels using hasdata/read pattern
reset(cwtStore);
mat = zeros(meta.nChannels, meta.nSamples, nBands);
    ci = 0;
    while hasdata(cwtStore)
        x = read(cwtStore);
        ci = ci + 1;
        % Pre-allocate on first read  
        mat(ci, :, :) = x;
    end
reset(cwtStore);


bandsPath = fullfile(subjectPath, "bands.mat");

% --- Rename variable to X before saving ---
X = mat;                      % mat is your 270 x nSamples x 5 array
save(bandsPath, "X", "-v7.3");
fprintf('\n============================================================\n');
fprintf('Saved bands for subject: %s\n', subjectId);
fprintf('============================================================\n');

%% 2) Make window metadata
winSec  = 20;
winSamp = sfreq * winSec;
hopSamp = winSamp;
nSamples = meta.nSamples;  % should equal size(X,2)
nChannels = meta.nChannels;
bandNames = string(fieldnames(struct('delta',[],'theta',[],'alpha',[],'beta',[],'gamma1',[])));
nBands    = numel(bandNames);

startIdx = (1:hopSamp:(nSamples - winSamp + 1))';
stopIdx  = startIdx + winSamp - 1;
nWindows = numel(startIdx);
window       = (1:nWindows)';
tStartSec    = (startIdx - 1) / sfreq;
tStopSec     = (stopIdx  - 1) / sfreq;
durationSec  = repmat(winSec, nWindows, 1);
sampleStart  = startIdx;
sampleStop   = stopIdx;
samplesPerWin = repmat(winSamp, nWindows, 1);

winTbl = table(window, sampleStart, sampleStop, samplesPerWin, ...
               tStartSec, tStopSec, durationSec);

% IMPORTANT: make it return cells, then unwrap
metaDs = arrayDatastore(winTbl, ...
    "IterationDimension", 1, ...
    "OutputType", "cell");
m = matfile(bandsPath);
segDs = transform(metaDs, @(c) makeWindowStruct(c{1}, m, sfreq, ...
    nChannels, bandNames));

%% Load first window
reset(segDs);
w1 = read(segDs);

size(w1.X)             % expected: 270 x 12000 x 5
w1.window              % expected: 1
w1.tStartSec           % expected: 0
w1.tStopSec            % expected: 19.998...
w1.durationSec         % expected: 20
w1.sfreq               % expected: 600
w1.nChannels           % expected: 270
w1.bandNames           % expected: ["delta","theta","alpha","beta","gamma1"]

%%
protocolPath = "Z:\brainstorm_protocols\TutorialOmega2";
db = loadBrainstorm(protocolPath, ...
    TimefreqPattern = struct('file', "timefreq", 'comment', "relative"), ...
    ResultPattern   = struct('file', "results_", 'comment', ""), ...
    LoadSourceMapping = true);
% Segment & resampling
segmentStart = 0;       % seconds
segmentEnd   = 300;     % seconds (5 min)
resampleHz   = 600;     % downsample from 2400 Hz
nSubjects = numel(db.subjects);
%% 
for si=3:nSubjects
subj = db.subjects(si); 
sm = subj.sourceMapping;
subjectId = subj.name;
[X, K, ~, ~, ~] = readSourceSegment(sm, segmentStart, segmentEnd, ...
                AsDatastore=false, Resample=resampleHz);
subjectPath  = fullfile(analysisRoot, subjectId);
sensorsPath = fullfile(subjectPath, "sensors.mat");
save(sensorsPath, "X", "-v7.3");
fprintf('\n============================================================\n');
fprintf('Saved sensors for subject: %s\n', subjectId);
fprintf('============================================================\n');
end

%%
groupPath    = fullfile(analysisRoot, "group");

fs5root      = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf";
[lhSphere, ~] = mne_read_surface(fullfile(fs5root, 'lh.sphere.reg'));
[rhSphere, ~] = mne_read_surface(fullfile(fs5root, 'rh.sphere.reg'));
[vertices, faces] = freesurfer_read_surf(fullfile(fs5root,"lh.pial"));
M=bct.Manifold(vertices,faces);
lh.topo = M.topology;
lh.geom = M.geometry('includeDual', true);
lh.ops=M.operators;
lh.eigen=M.eigenmodes(1000);
lh.M= M;
lh.vertices = lh.M.Vertices;
lh.faces = lh.M.Faces;
lh.sphere = lhSphere;

clear M vertices faces;
[vertices, faces] = freesurfer_read_surf(fullfile(fs5root,"rh.pial"));
M=bct.Manifold(vertices,faces);
rh.topo = M.topology;
rh.geom = M.geometry('includeDual', true);
rh.ops=M.operators;
rh.eigen=M.eigenmodes(1000);
rh.M= M;
rh.vertices = M.Vertices;
rh.faces = M.Faces;
rh.sphere = rhSphere;

fsaverage5.rh = rh;
fsaverage5.lh = lh;
save(fullfile(groupPath,"fsaverage5.mat"), "fsaverage5", "-v7.3");
S1 = load(fullfile(groupPath,"fsaverage5.mat"), "lh");
%%

protocolPath = "Z:\brainstorm_protocols\TutorialOmega2";
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
db = loadBrainstorm(protocolPath, ...
    TimefreqPattern = struct('file', "timefreq", 'comment', "relative"), ...
    ResultPattern   = struct('file', "results_", 'comment', ""), ...
    LoadSourceMapping = true);
nSubjects = numel(db.subjects);

for si=2:nSubjects
subj = db.subjects(si);
subjectId = subj.name;
subjectPath  = fullfile(analysisRoot, subjectId);
sm = subj.sourceMapping;
sSurf=load(sm.surfaceFullPath);
meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
surfPath = fullfile(subjectPath, "pialsurf.mat");
save(surfPath, "sSurf", "-v7.3");
end