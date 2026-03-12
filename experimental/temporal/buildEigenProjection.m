function eigen = buildEigenProjection(subjectPath, sourceMapping, fsaverage5, opts)
%BUILDEIGENPROJECTION Compose and save the sensor→eigenmode projection.
%
%   eigen = buildEigenProjection(subjectPath, sourceMapping, fsaverage5)
%   eigen = buildEigenProjection(__, Name=Value)
%
%   Computes QK = U' * M * W * K per hemisphere and packs the result into
%   a unified 'eigen' struct, then saves it to <subjectPath>/eigen.mat.
%
%   Chain (per hemisphere):
%       K  : [nSources × nChannels]  imaging kernel (loaded from subjectPath)
%       W  : [nDest    × nSources]   sphere interpolation (subject → fsaverage)
%       M  : [nDest    × nDest]      FEM mass matrix on fsaverage
%       U  : [nDest    × k]          Laplace–Beltrami eigenmodes on fsaverage
%       QK : [k        × nChannels]  pre-composed sensor→eigenmode mapping
%
%   After saving, any downstream script can simply:
%       eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;
%       coeffs = eigen.lh.imagingKernel * sensorData;
%
%   Inputs:
%       subjectPath    - char/string path to the subject analysis folder.
%                        Must contain ImagingKernel.mat (variable K).
%       sourceMapping  - sourceMapping struct from loadBrainstorm (has
%                        .Reg.Sphere.Vertices and .Atlas). Passed through
%                        to buildProjectionMatrix.
%       fsaverage5     - struct with .lh and .rh, each containing:
%                          .sphere                    [nDest × 3]
%                          .eigen.eigenvectors.value   [nDest × k]
%                          .eigen.eigenvalues.value    [k × 1]
%                          .ops.mass.value             [nDest × nDest]
%
%   Name-Value Options:
%       Save           - logical, whether to save eigen.mat (default: true)
%       Verbose        - logical, print progress messages   (default: true)
%
%   Output:
%       eigen          - struct with fields:
%         .lh / .rh      .imagingKernel  [k × nChannels]
%                         .eigenvalues    [k × 1]
%                         .nModes         scalar
%                         .nChannels      scalar
%                         .nDest          scalar
%         .full           (concatenation of lh + rh)
%         .projInfo       provenance from buildProjectionMatrix
%
%   Example:
%       fsaverage5 = load("fsaverage5.mat");
%       db = loadBrainstorm(protocolPath, LoadSourceMapping=true);
%       for si = 1:numel(db.subjects)
%           subj = db.subjects(si);
%           buildEigenProjection( ...
%               fullfile(analysisRoot, subj.name), ...
%               subj.sourceMapping, fsaverage5);
%       end
%
%   See also buildProjectionMatrix, loadBrainstorm

arguments
    subjectPath   (1,1) string {mustBeFolder}
    sourceMapping (1,1) struct
    fsaverage5    (1,1) struct
    opts.Save     (1,1) logical = true
    opts.Verbose  (1,1) logical = true
end

% ---- Load imaging kernel K ----
kernelFile = fullfile(subjectPath, "ImagingKernel.mat");
assert(isfile(kernelFile), 'ImagingKernel.mat not found in %s', subjectPath);
K = load(kernelFile).K;

if opts.Verbose
    fprintf('Subject:    %s\n', subjectPath);
    fprintf('Kernel K:   [%d × %d]  (%d sources, %d channels)\n', size(K), size(K));
end

% ---- Build sphere interpolation W ----
[W, projInfo] = buildProjectionMatrix(sourceMapping, ...
    fsaverage5.lh.sphere, fsaverage5.rh.sphere);

% ---- Compose WK = W * K and split hemispheres ----
WK = W * K;
WK_lh = WK(1:projInfo.nDestL, :);
WK_rh = WK(projInfo.nDestL+1:end, :);
clear WK W;

% ---- Compose QK = U' * M * WK per hemisphere ----
eigen.lh.imagingKernel = (fsaverage5.lh.eigen.eigenvectors.value' ...
                        * fsaverage5.lh.ops.mass.value) * WK_lh;
eigen.lh.eigenvalues   = fsaverage5.lh.eigen.eigenvalues.value(:);
eigen.lh.nModes        = size(eigen.lh.imagingKernel, 1);
eigen.lh.nChannels     = size(eigen.lh.imagingKernel, 2);
eigen.lh.nDest         = projInfo.nDestL;

eigen.rh.imagingKernel = (fsaverage5.rh.eigen.eigenvectors.value' ...
                        * fsaverage5.rh.ops.mass.value) * WK_rh;
eigen.rh.eigenvalues   = fsaverage5.rh.eigen.eigenvalues.value(:);
eigen.rh.nModes        = size(eigen.rh.imagingKernel, 1);
eigen.rh.nChannels     = size(eigen.rh.imagingKernel, 2);
eigen.rh.nDest         = projInfo.nDestR;

eigen.full.imagingKernel = [eigen.lh.imagingKernel; eigen.rh.imagingKernel];
eigen.full.eigenvalues   = [eigen.lh.eigenvalues;   eigen.rh.eigenvalues];
eigen.full.nModes        = eigen.lh.nModes + eigen.rh.nModes;
eigen.full.nChannels     = eigen.lh.nChannels;

eigen.projInfo = projInfo;

if opts.Verbose
    fprintf('eigen.lh:   [%d × %d]\n', size(eigen.lh.imagingKernel));
    fprintf('eigen.rh:   [%d × %d]\n', size(eigen.rh.imagingKernel));
    fprintf('eigen.full: [%d × %d]\n', size(eigen.full.imagingKernel));
end

% ---- Save ----
if opts.Save
    outFile = fullfile(subjectPath, "eigen.mat");
    save(outFile, "eigen", "-v7.3");
    if opts.Verbose
        fprintf('Saved → %s\n', outFile);
    end
end

end
