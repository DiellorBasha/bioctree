function [subj] = in_fs_read_subject(subject_dir, subject_name, parameters)

% in_fs_read_subject - reads FreeSurfer subject cortical surface data
%
% Enhanced version with support for spherical surfaces and sulcal depth data.
% This function and its dependencies are based on code from the 
% bioelectromagnetism toolbox (https://eeg.sourceforge.net/bioelectromagnetism.html)
% originally developed by Darren Weber and contributors.
%
% USAGE: [subj] = in_fs_read_subject(subject_dir, subject_name, parameters)
%
% This function reads FreeSurfer subject data including surfaces, 
% curvatures, and anatomical overlays. Enhanced version with support
% for spherical surfaces (lh.sphere, lh.sphere.reg) and sulcal depth.
%
% INPUTS:
%   subject_dir  - Path to subjects directory (default: test-data/freesurfer)
%   subject_name - Subject name (default: fsaverage)
%   parameters   - Structure with fields:
%                  .surface_list   - Cell array of surfaces to load
%                                   (default: {'orig','pial','white','sphere','sphere.reg'})
%                  .curv_list      - Cell array of curvature files
%                                   (default: {'curv','thickness','sulc','area'})
%                  .annotation_list - Cell array of annotation files
%                                   (default: {'aparc'})
%                  .verbose        - Verbose output (default: 1)
%
% OUTPUT:
%   subj - Structure containing surface data with fields:
%          .subjectpath - Full path to subject directory
%          .lh/.rh - Left/right hemisphere structures containing:
%            .surface - Cell array of surface structures with:
%              .name      - Surface name
%              .vertices  - Vertex coordinates (Nx3)
%              .faces     - Face indices (Mx3)
%            .curv - Cell array of curvature structures with:
%              .name   - Curvature name
%              .data   - Curvature values per vertex
%            .annotation - Cell array of annotation structures
%
% EXAMPLES:
%   % Load default surfaces and data
%   subj = in_fs_read_subject();
%   
%   % Load specific surfaces
%   params.surface_list = {'orig', 'sphere'};
%   params.curv_list = {'curv', 'sulc', 'area'};
%   subj = in_fs_read_subject('test-data/freesurfer', 'fsaverage', params);
%
% See also: in_fs_read_surf, in_fs_read_curv, in_fs_read_sulc

% Enhanced version for bioctree project
% Adds support for spherical surfaces and sulcal depth data

if nargin < 1 || isempty(subject_dir)
    subject_dir = 'test-data\freesurfer';
end

if nargin < 2 || isempty(subject_name)
    subject_name = 'fsaverage';
end

if nargin < 3
    parameters = struct();
end

% Default parameters
if ~isfield(parameters, 'surface_list')
    parameters.surface_list = {'orig', 'pial', 'white', 'sphere', 'sphere.reg'};
end

if ~isfield(parameters, 'curv_list')
    parameters.curv_list = {'curv', 'thickness', 'sulc', 'area'};
end

if ~isfield(parameters, 'annotation_list')
    parameters.annotation_list = {'aparc'};
end

if ~isfield(parameters, 'verbose')
    parameters.verbose = 1;
end

% Initialize output structure
subj = struct();
subj.filename = fullfile(subject_dir, subject_name);
subj.subjectpath = fullfile(subject_dir, subject_name);

if parameters.verbose
    fprintf('\nReading FreeSurfer subject: %s\n', subject_name);
    fprintf('Subject directory: %s\n', subj.subjectpath);
end

% Check if subject directory exists
if ~exist(subj.subjectpath, 'dir')
    error('Subject directory does not exist: %s', subj.subjectpath);
end

% Define hemispheres
hemispheres = {'lh', 'rh'};

for h = 1:length(hemispheres)
    hemi = hemispheres{h};
    
    if parameters.verbose
        fprintf('\nProcessing hemisphere: %s\n', hemi);
    end
    
    % Initialize hemisphere structure
    subj.(hemi) = struct();
    
    % Load surfaces
    for s = 1:length(parameters.surface_list)
        surface_name = parameters.surface_list{s};
        surface_file = fullfile(subj.subjectpath, 'surf', sprintf('%s.%s', hemi, surface_name));
        
        if exist(surface_file, 'file')
            if parameters.verbose
                fprintf('  Loading surface: %s\n', surface_name);
            end
            
            try
                [vertices, faces] = in_fs_read_surf(surface_file);
                
                % Store surface data directly in structure
                % Handle special case for sphere.reg (convert to valid field name)
                field_name = surface_name;
                if strcmp(surface_name, 'sphere.reg')
                    field_name = 'sphere_reg';
                end
                
                subj.(hemi).(field_name).vertices = vertices;
                subj.(hemi).(field_name).faces = faces;
                
                if parameters.verbose
                    fprintf('    Vertices: %d, Faces: %d\n', size(vertices,1), size(faces,1));
                end
                
            catch ME
                if parameters.verbose
                    fprintf('    Warning: Could not load surface %s: %s\n', surface_name, ME.message);
                end
            end
        else
            if parameters.verbose
                fprintf('    Warning: Surface file not found: %s\n', surface_file);
            end
        end
    end
    
    % Load curvature and morphometric data
    for c = 1:length(parameters.curv_list)
        curv_name = parameters.curv_list{c};
        
        % All curvature files are in surf directory
        curv_file = fullfile(subj.subjectpath, 'surf', sprintf('%s.%s', hemi, curv_name));
        
        if exist(curv_file, 'file')
            if parameters.verbose
                fprintf('  Loading %s data: %s\n', curv_name, curv_name);
            end
            
            try
                if strcmp(curv_name, 'sulc')
                    [curv_data] = in_fs_read_sulc(curv_file);
                else
                    [curv_data] = in_fs_read_curv(curv_file);
                end
                
                % Store curvature data directly in structure
                subj.(hemi).(curv_name).data = curv_data;
                
                if parameters.verbose
                    fprintf('    Data points: %d (range: %.3f to %.3f)\n', ...
                        length(curv_data), min(curv_data), max(curv_data));
                end
                
            catch ME
                if parameters.verbose
                    fprintf('    Warning: Could not load %s data: %s\n', curv_name, ME.message);
                end
            end
        else
            if parameters.verbose
                fprintf('    Warning: %s file not found: %s\n', curv_name, curv_file);
            end
        end
    end
    
    % Load annotations
    for a = 1:length(parameters.annotation_list)
        annot_name = parameters.annotation_list{a};
        annot_file = fullfile(subj.subjectpath, 'label', sprintf('%s.%s.annot', hemi, annot_name));
        
        if exist(annot_file, 'file')
            if parameters.verbose
                fprintf('  Loading annotation: %s\n', annot_name);
            end
            
            try
                [vertices_labels] = in_fs_read_annotation(annot_file);
                
                % Store annotation data directly in structure
                subj.(hemi).(annot_name).vertices = vertices_labels;
                
                if parameters.verbose
                    fprintf('    Vertex labels: %d values\n', length(vertices_labels));
                end
                
            catch ME
                if parameters.verbose
                    fprintf('    Warning: Could not load annotation %s: %s\n', annot_name, ME.message);
                end
            end
        else
            if parameters.verbose
                fprintf('    Warning: Annotation file not found: %s\n', annot_file);
            end
        end
    end
end

if parameters.verbose
    fprintf('\nFreeSurfer subject loading complete.\n');
    
    % Summary
    for h = 1:length(hemispheres)
        hemi = hemispheres{h};
        fprintf('\n%s hemisphere summary:\n', upper(hemi));
        
        % Count surfaces
        surface_count = 0;
        for s = 1:length(parameters.surface_list)
            field_name = parameters.surface_list{s};
            if strcmp(field_name, 'sphere.reg')
                field_name = 'sphere_reg';
            end
            if isfield(subj.(hemi), field_name)
                surface_count = surface_count + 1;
            end
        end
        fprintf('  Surfaces loaded: %d\n', surface_count);
        
        % Count curvature data
        curv_count = 0;
        for c = 1:length(parameters.curv_list)
            if isfield(subj.(hemi), parameters.curv_list{c})
                curv_count = curv_count + 1;
            end
        end
        fprintf('  Curvature data: %d\n', curv_count);
        
        % Count annotations
        annot_count = 0;
        for a = 1:length(parameters.annotation_list)
            if isfield(subj.(hemi), parameters.annotation_list{a})
                annot_count = annot_count + 1;
            end
        end
        fprintf('  Annotations: %d\n', annot_count);
    end
end

end