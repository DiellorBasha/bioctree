MriFileSrc='C:\Users\diell\ownSyncFolder\PAD7_test\anat\sub-MTL0002\subjectimage_T1_reslice.mat'
[sSubject, iSubject] = bst_get('MriFile', MriFileSrc);
Condition = 'GSP_Wavelet_Curvature';
sMriSrc = in_mri_bst(MriFileSrc);
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, Condition));
if isempty(iStudy)
    iStudy = db_add_condition(sSubject.Name, Condition);
    sStudy = bst_get('Study', iStudy);
end
% Collect all file names
allFiles = {sSubject.Surface.FileName};
% Find indices for each surface type
idxPial  = find(~cellfun('isempty', regexp(allFiles, 'cortex_pial_low\.mat$', 'once')), 1);
 pialFile = allFiles{idxPial};
 sPial  = in_tess_bst(pialFile);
 map=dd(:,15);

 map=Sf(:,3);
% === STORE AS REGULAR SOURCE FILE ===
    ResultsMat = db_template('resultsmat');
    if size(map, 2) > 1
        ResultsMat.ImageGridAmp  = map;
    else
        ResultsMat.ImageGridAmp  = [map, map];
    end
    ResultsMat.ImagingKernel = [];
    FileType = 'results';
    % Time vector
    if isempty(TimeVector) || (length(TimeVector) ~= size(ResultsMat.ImageGridAmp,2))
        ResultsMat.Time = 0:(size(ResultsMat.ImageGridAmp,2)-1);
    else
        ResultsMat.Time = TimeVector;
    end
% Fix identical time points
if (length(ResultsMat.Time) == 2) && (ResultsMat.Time(1) == ResultsMat.Time(2))
    ResultsMat.Time(2) = ResultsMat.Time(2) + 0.001;
end

% === SAVE NEW FILE ===
ResultsMat.Comment       = Comment;
ResultsMat.DataFile      = [];
ResultsMat.SurfaceFile   = file_win2unix(file_short(pialFile));
ResultsMat.HeadModelFile = [];
ResultsMat.nComponents   = 1;
ResultsMat.DisplayUnits  = DisplayUnits;
if isequal(DisplayUnits, 's')
    ResultsMat.ColormapType = 'time';
end
ResultsMat.HeadModelType = 'surface';
% History
ResultsMat = bst_history('add', ResultsMat, 'project', ['Projected from: ' sMriSrc.Comment]);
% Create output filename
OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType, '_', ResultsMat.HeadModelType, '_', file_standardize(Comment)]);
% Save new file
bst_save(OutputFile, ResultsMat, 'v7');
% Update database
db_add_data(iStudy, OutputFile, ResultsMat);

% Update tree
panel_protocols('UpdateNode', 'Study', iStudy);
% Save database
db_save();


view_surface_data(pialFile, file_short(OutputFile))
