function [V_new, F_new, maskCortex, used] = bct_mask_medial_wall(M, fsdir, hemi)
% bct_mask_medial_wall
%   Remove FreeSurfer medial wall by keeping only cortex vertices from
%   <hemi>.cortex.label and returning a compact (reindexed) submesh.
%
% Inputs
%   M     : struct/object with fields:
%             - Vertices (N×3)
%             - Faces    (K×3)  (1-based indexing)
%   fsdir : path to FreeSurfer subject directory (e.g., .../fsaverage5)
%   hemi  : 'lh' or 'rh'
%
% Outputs
%   V_new      : compact vertex array (Nc×3)
%   F_new      : compact face array (Kc×3), reindexed into V_new
%   maskCortex : N×1 logical mask in original indexing (true = cortex)
%   used       : indices of original vertices retained in the compact mesh
%
% Requirements
%   FreeSurfer's freesurfer_read_label.m must be on MATLAB path.

arguments
    M
    fsdir (1,:) char
    hemi (1,:) char {mustBeMember(hemi, {'lh','rh'})}
end

% --- Read cortex label (FreeSurfer label files are 0-based vertex indices)
labelFile = fullfile(fsdir, 'label', sprintf('%s.cortex.label', hemi));
if ~exist(labelFile, 'file')
    error('Cortex label file not found: %s', labelFile);
end

L = freesurfer_read_label([], labelFile);     % typically n×5; first column is vertex index (0-based)
if isempty(L) || size(L,2) < 1
    error('freesurfer_read_label returned empty/invalid output for: %s', labelFile);
end

cortexVerts = L(:,1) + 1;          % convert to MATLAB 1-based vertex indices

% --- Build vertex mask in the original mesh indexing
N = size(M.Vertices, 1);
maskCortex = false(N, 1);

% Guard against out-of-range indices
cortexVerts = cortexVerts(cortexVerts >= 1 & cortexVerts <= N);
maskCortex(cortexVerts) = true;    % TRUE = keep (cortex), FALSE = medial wall

% --- Keep faces fully inside cortex
faceKeep = all(maskCortex(M.Faces), 2);
F_keep = M.Faces(faceKeep, :);

% --- Build compact (reindexed) mesh
used = unique(F_keep(:));          % original vertex indices used by kept faces

newIdx = zeros(N, 1);
newIdx(used) = 1:numel(used);

V_new = M.Vertices(used, :);
F_new = newIdx(F_keep);

end
