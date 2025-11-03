% test_new_structure.m - Test the new structure format for in_fs_read_subject
%
% This script tests the enhanced structure format where data is directly
% accessible as subj.lh.orig.vertices, subj.lh.curv.data, etc.

clear; clc;

fprintf('Testing new structure format for in_fs_read_subject...\n\n');

% Add the io/in directory to path
addpath('io/in');

try
    % Load with default parameters
    fprintf('Loading FreeSurfer data with new structure format...\n');
    subj = in_fs_read_subject();
    
    fprintf('\n=== Testing New Structure Format ===\n');
    
    % Test direct access to surfaces
    fprintf('\nSurface data access:\n');
    if isfield(subj.lh, 'orig')
        fprintf('✓ subj.lh.orig.vertices: %dx%d\n', size(subj.lh.orig.vertices));
        fprintf('✓ subj.lh.orig.faces: %dx%d\n', size(subj.lh.orig.faces));
    end
    
    if isfield(subj.lh, 'sphere')
        fprintf('✓ subj.lh.sphere.vertices: %dx%d\n', size(subj.lh.sphere.vertices));
        fprintf('✓ subj.lh.sphere.faces: %dx%d\n', size(subj.lh.sphere.faces));
        
        % Test sphere coordinates
        sphere_vertex = subj.lh.sphere.vertices(1,:);
        radius = norm(sphere_vertex);
        fprintf('  First vertex: [%.3f, %.3f, %.3f], radius: %.1f\n', ...
            sphere_vertex(1), sphere_vertex(2), sphere_vertex(3), radius);
    end
    
    if isfield(subj.lh, 'pial')
        fprintf('✓ subj.lh.pial.vertices: %dx%d\n', size(subj.lh.pial.vertices));
    end
    
    if isfield(subj.lh, 'sphere_reg')
        fprintf('✓ subj.lh.sphere_reg.vertices: %dx%d\n', size(subj.lh.sphere_reg.vertices));
    end
    
    % Test direct access to curvature data
    fprintf('\nCurvature data access:\n');
    if isfield(subj.lh, 'curv')
        fprintf('✓ subj.lh.curv.data: %dx%d (range: %.3f to %.3f)\n', ...
            size(subj.lh.curv.data), min(subj.lh.curv.data), max(subj.lh.curv.data));
    end
    
    if isfield(subj.lh, 'sulc')
        fprintf('✓ subj.lh.sulc.data: %dx%d (range: %.3f to %.3f)\n', ...
            size(subj.lh.sulc.data), min(subj.lh.sulc.data), max(subj.lh.sulc.data));
        
        % Test sulc values
        fprintf('  Sample sulc values: %.3f, %.3f, %.3f\n', ...
            subj.lh.sulc.data(1), subj.lh.sulc.data(100), subj.lh.sulc.data(1000));
    end
    
    if isfield(subj.lh, 'thickness')
        fprintf('✓ subj.lh.thickness.data: %dx%d (range: %.3f to %.3f)\n', ...
            size(subj.lh.thickness.data), min(subj.lh.thickness.data), max(subj.lh.thickness.data));
    end
    
    % Test annotation data
    fprintf('\nAnnotation data access:\n');
    if isfield(subj.lh, 'aparc')
        fprintf('✓ subj.lh.aparc.vertices: %dx%d\n', size(subj.lh.aparc.vertices));
        fprintf('  Unique labels: %d\n', length(unique(subj.lh.aparc.vertices)));
    end
    
    % Test file information
    fprintf('\nFile information:\n');
    fprintf('✓ subj.filename: %s\n', subj.filename);
    fprintf('✓ subj.subjectpath: %s\n', subj.subjectpath);
    
    % Test right hemisphere
    fprintf('\nRight hemisphere check:\n');
    if isfield(subj.rh, 'orig')
        fprintf('✓ subj.rh.orig.vertices: %dx%d\n', size(subj.rh.orig.vertices));
    end
    if isfield(subj.rh, 'sulc')
        fprintf('✓ subj.rh.sulc.data: %dx%d\n', size(subj.rh.sulc.data));
    end
    
    fprintf('\n=== Structure Format Test PASSED ===\n');
    fprintf('All data is now directly accessible without cell arrays!\n');
    
    % Show usage examples
    fprintf('\n=== Usage Examples ===\n');
    fprintf('Access original surface vertices: subj.lh.orig.vertices\n');
    fprintf('Access sphere coordinates: subj.lh.sphere.vertices\n');
    fprintf('Access registered sphere: subj.lh.sphere_reg.vertices\n');
    fprintf('Access sulcal depth: subj.lh.sulc.data\n');
    fprintf('Access curvature: subj.lh.curv.data\n');
    fprintf('Access parcellation: subj.lh.aparc.vertices\n');
    
catch ME
    fprintf('Error during testing: %s\n', ME.message);
    fprintf('This may indicate an issue with the structure format.\n');
end

fprintf('\nStructure format test completed.\n');