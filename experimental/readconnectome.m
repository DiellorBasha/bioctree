connFolderBase = "C:\CodingProjects\bioctree\data\tractography-osfstorage-archive\"

connFolder = "C:\CodingProjects\bioctree\data\tractography-osfstorage-archive\10 High-resolution connectomes - 234 nodes"
connFolder2 = "C:\CodingProjects\bioctree\data\tractography-osfstorage-archive\100 Low-resolution connectomes - 84 nodes"

connFile=dir(connFolder); connMeta = dir(connFolderBase);
conn1 = readtable(fullfile(connFolder, connFile(3).name));
conn2 = readtable(fullfile(connFolder2, connFile(3).name));
nodeLabels = readmatrix(fullfile(connFolderBase, connMeta(5).name));
subjectIDs = readmatrix(fullfile(connFolderBase, connMeta(6).name));

conn1=table2array(conn1);
%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 9);
% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = " ";
% Specify column names and types
opts.VariableNames = ["x_No_", "Label", "Name_", "R", "G", "B", "A", "Var8", "Var9"];
opts.SelectedVariableNames = ["x_No_", "Label", "Name_", "R", "G", "B"];
opts.VariableTypes = ["double", "string", "double", "double", "double", "double", "string", "string", "string"];
% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts.ConsecutiveDelimitersRule = "join";
opts.LeadingDelimitersRule = "ignore";
% Specify variable properties
opts = setvaropts(opts, ["Label", "A", "Var8", "Var9"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Label", "A", "Var8", "Var9"], "EmptyFieldRule", "auto");
% Import the data
fsLUT = readtable("C:\CodingProjects\bioctree\data\tractography-osfstorage-archive\freesurferColorLUT.txt.txt", opts);
fsLUT = renamevars(fsLUT, ["x_No_", "Name_"],  ["Number", "Name"]);
aseg='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\label\lh.aparc.annot';
[verticesfs, labelfs, colortablefs] = freesurfer_read_annotation_ctab(aseg);
%%
[verticesfs, labelfs, colortablefs] = freesurfer_read_annotation_ctab(aseg);
conn2 = readtable(fullfile(connFolder2, connFile(3).name));
nodeLabels = readmatrix(fullfile(connFolderBase, connMeta(5).name));
fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[vertices, faces] = freesurfer_read_surf(fs4path);

size(conn2)

%%
nV = size(vertices,1);
assert(numel(labelfs) == nV, 'labelfs must be nV×1 matching fsaverage vertices');

Wroi = table2array(conn2);
size(Wroi)   % should be 84×84
fsNames = string(colortablefs.struct_names(:));     % ROI names, e.g. "bankssts"
fsCodes = colortablefs.table(:,5);                 % the packed annotation codes (common FS convention)

% Map each vertex label code -> ROI row in fsNames
[tf, v2roi_fs] = ismember(labelfs, fsCodes);
v2roi_fs(~tf) = 0;   % 0 = unlabeled/unknown
roiVerts_fs = accumarray(max(v2roi_fs,1), (1:nV)', [], @(x){x});
% roiVerts_fs{k} is the vertex index list for fsNames(k)
nodeTbl = readtable(fullfile(connFolderBase, connMeta(5).name), 'FileType','text');

% Inspect variable names once:
nodeTbl.Properties.VariableNames
head(nodeTbl)
normName = @(s) lower( regexprep( regexprep(s, "^(ctx-[lr]h-|lh-|rh-)", ""), "[^a-z0-9]", "" ) );

osfNames = arrayfun(normName, osfNamesRaw);
fsNamesN = arrayfun(normName, fsNames);
%%
[isMatch, osf2fs] = ismember(osfNames, fsNamesN);

% Report problems
fprintf('Matched %d/%d OSF nodes to fsaverage DK names\n', nnz(isMatch), numel(isMatch));
if any(~isMatch)
    disp("Unmatched OSF names (first 20):");
    disp(osfNamesRaw(find(~isMatch,20)));
end

%%
% If node table has 85 nodes but Wroi is 84, drop the extra row by comparing:
if height(nodeTbl) ~= size(Wroi,1)
    warning('nodeTbl rows (%d) != Wroi size (%d). You must align them.', height(nodeTbl), size(Wroi,1));
    % Most common: first row is non-data or "unknown". Try dropping rows to match:
    nodeTbl = nodeTbl(1:size(Wroi,1), :);  % or nodeTbl(2:end,:) depending on file
    osfNamesRaw = string(nodeTbl.name);
    osfNames = arrayfun(normName, osfNamesRaw);
    [isMatch, osf2fs] = ismember(osfNames, fsNamesN);
end


%%

nV = size(vertices,1);
K  = 40;            % edges per ROI-pair (tune this)
minW = 0;           % threshold (optional)

I = []; J = []; S = [];

for a = 1:size(Wroi,1)
    fa = osf2fs(a);
    if fa==0, continue; end
    Va = roiVerts_fs{fa};
    if isempty(Va), continue; end

    for b = a+1:size(Wroi,2)
        w = Wroi(a,b);
        if w <= minW, continue; end

        fb = osf2fs(b);
        if fb==0, continue; end
        Vb = roiVerts_fs{fb};
        if isempty(Vb), continue; end

        k = min([K, numel(Va), numel(Vb)]);
        ia = Va(randi(numel(Va), k, 1));
        ib = Vb(randi(numel(Vb), k, 1));

        I = [I; ia; ib];
        J = [J; ib; ia];
        S = [S; repmat(w/k, k, 1); repmat(w/k, k, 1)];
    end
end

W_lr = sparse(I, J, S, nV, nV);
W_lr = max(W_lr, W_lr');   % ensure symmetric
