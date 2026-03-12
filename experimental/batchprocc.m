analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
protocolPath = "Z:\brainstorm_protocols\TutorialOmega2";
db = loadBrainstorm(protocolPath, ...
    TimefreqPattern = struct('file', "timefreq", 'comment', "relative"), ...
    ResultPattern   = struct('file', "results_", 'comment', ""), ...
    LoadSourceMapping = true);
nSubjects = numel(db.subjects);
%%
% Basic
for si = 1:5
    subj = db.subjects(si);
    subjName = subj.name;
% With save
R = eigenmodeFilter(fullfile(analysisRoot, subjName), ...
    SavePath=fullfile(analysisRoot, subjName, "filter_mxhat.mat"));
end
%%

for si = 1:5
    subj = db.subjects(si);
    subjName = subj.name;
% With save
R = eigenmodeFilter(fullfile(analysisRoot, subjName), ...
    SavePath=fullfile(analysisRoot, subjName, "filter_heat.mat"), ...
    KernelName="Heat", NScales=6);
end
%%
results = eigenmodeAnalysis(analysisRoot, subjectName, Save=true);

% Custom kernel/scales
R = eigenmodeFilter(subjectPath, KernelName="Heat", NScales=6);