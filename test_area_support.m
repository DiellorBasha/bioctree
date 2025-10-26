% test_area_support.m - Test script for area file support in in_fs_read_subject
%
% This script tests the area file loading functionality

clear; clc;

fprintf('Testing FreeSurfer area file support...\n\n');

% Add the io/in directory to path
addpath('io/in');

try
    % Load with default parameters (now includes area)
    fprintf('Loading FreeSurfer data with area support...\n');
    subj = in_fs_read_subject();
    
    fprintf('\n=== FreeSurfer Data Summary ===\n');
    
    % Display all loaded surfaces
    fprintf('\nSurfaces loaded:\n');
    fprintf('✓ subj.lh.orig.vertices: %dx%d\n', size(subj.lh.orig.vertices));
    fprintf('✓ subj.lh.pial.vertices: %dx%d\n', size(subj.lh.pial.vertices));
    fprintf('✓ subj.lh.white.vertices: %dx%d\n', size(subj.lh.white.vertices));
    fprintf('✓ subj.lh.sphere.vertices: %dx%d\n', size(subj.lh.sphere.vertices));
    fprintf('✓ subj.lh.sphere_reg.vertices: %dx%d\n', size(subj.lh.sphere_reg.vertices));
    
    % Display all loaded morphometric data
    fprintf('\nMorphometric data loaded:\n');
    fprintf('✓ subj.lh.curv.data: %dx%d (range: %.3f to %.3f)\n', ...
        size(subj.lh.curv.data), min(subj.lh.curv.data), max(subj.lh.curv.data));
    fprintf('✓ subj.lh.thickness.data: %dx%d (range: %.3f to %.3f mm)\n', ...
        size(subj.lh.thickness.data), min(subj.lh.thickness.data), max(subj.lh.thickness.data));
    fprintf('✓ subj.lh.sulc.data: %dx%d (range: %.3f to %.3f)\n', ...
        size(subj.lh.sulc.data), min(subj.lh.sulc.data), max(subj.lh.sulc.data));
    
    % Test area data specifically
    if isfield(subj.lh, 'area')
        fprintf('✓ subj.lh.area.data: %dx%d (range: %.6f to %.6f mm²)\n', ...
            size(subj.lh.area.data), min(subj.lh.area.data), max(subj.lh.area.data));
        
        % Calculate total surface areas
        total_lh_area = sum(subj.lh.area.data);
        total_rh_area = sum(subj.rh.area.data);
        total_area = total_lh_area + total_rh_area;
        
        fprintf('\nSurface area analysis:\n');
        fprintf('  Left hemisphere total area: %.2f mm²\n', total_lh_area);
        fprintf('  Right hemisphere total area: %.2f mm²\n', total_rh_area);
        fprintf('  Total cortical surface area: %.2f mm²\n', total_area);
        fprintf('  LH/RH area ratio: %.3f\n', total_lh_area / total_rh_area);
        
        % Sample area values at different cortical regions
        fprintf('\nSample vertex areas (LH):\n');
        sample_indices = [1, 1000, 10000, 50000, 100000];
        for i = 1:length(sample_indices)
            idx = sample_indices(i);
            fprintf('  Vertex %d: %.6f mm²\n', idx, subj.lh.area.data(idx));
        end
        
    else
        fprintf('✗ Area data not found!\n');
    end
    
    % Display annotation data
    if isfield(subj.lh, 'aparc')
        fprintf('\nParcellation data:\n');
        fprintf('✓ subj.lh.aparc.vertices: %dx%d\n', size(subj.lh.aparc.vertices));
        fprintf('  Unique regions: %d\n', length(unique(subj.lh.aparc.vertices)));
    end
    
    fprintf('\n=== Usage Examples ===\n');
    fprintf('Access surface area per vertex: subj.lh.area.data\n');
    fprintf('Calculate total surface area: sum(subj.lh.area.data)\n');
    fprintf('Find high-area vertices: find(subj.lh.area.data > 0.8)\n');
    fprintf('Correlate area with curvature: corr(subj.lh.area.data, subj.lh.curv.data)\n');
    
    % Test area-curvature correlation
    if isfield(subj.lh, 'area') && isfield(subj.lh, 'curv')
        area_curv_corr = corr(subj.lh.area.data, subj.lh.curv.data);
        fprintf('\nArea-curvature correlation (LH): r = %.3f\n', area_curv_corr);
        
        % Count high/low area vertices
        high_area_count = sum(subj.lh.area.data > 0.5);
        low_area_count = sum(subj.lh.area.data < 0.2);
        fprintf('High area vertices (>0.5 mm²): %d (%.1f%%)\n', ...
            high_area_count, 100 * high_area_count / length(subj.lh.area.data));
        fprintf('Low area vertices (<0.2 mm²): %d (%.1f%%)\n', ...
            low_area_count, 100 * low_area_count / length(subj.lh.area.data));
    end
    
    fprintf('\n=== Area File Support Test PASSED ===\n');
    
catch ME
    fprintf('Error during testing: %s\n', ME.message);
end

fprintf('\nArea file support test completed.\n');