folderPath = 'C:\Users\diell\ownSyncFolder\PAD7_test\anat'
    % Folders to exclude
    excluded = ["@default_subject", "Empty_room_noise", "Group_analysis"];
    
    % List all folders in the directory
    dirs = dir(folderPath);
    validDirs = dirs([dirs.isdir] & ~ismember({dirs.name}, {'.', '..'}) & ~ismember({dirs.name}, excluded));

    % Loop through each subject folder
    for k = 1:length(validDirs)
        subjectName = validDirs(k).name;
        subjectPath = fullfile(folderPath, subjectName);
        anatFile = fullfile(subjectPath, "tess_cortex_pial_low.mat");
        testDataDir='C:\CodingProjects\bioctree\test-data';
        mkdir(fullfile(testDataDir, subjectName));
        clear anat G
        anat=load(anatFile);
        save(fullfile(testDataDir, subjectName, "anat.mat"), "anat");
        V=anat.Vertices;
        VertConn=anat.VertConn;
        G=gsp_graph(VertConn,V);
        save(fullfile(testDataDir, subjectName, "gspanat.mat"), 'G', '-v7.3');
       
    end

