function [scaleStats, needsRescaling] = scale(mesh, ~, ~)
%SCALE Analyze mesh scale characteristics for unit detection
%
% Syntax:
%   [scaleStats, needsRescaling] = bct.manifold.health.measure.scale(mesh, ~, ~)
%
% Inputs:
%   mesh - Normalized mesh structure with V, F
%
% Outputs:
%   scaleStats       - Structure with scale metrics:
%                      .vertexExtent_min, .vertexExtent_max, .vertexExtent_range
%                      .edgeLength_median, .edgeLength_min, .edgeLength_max
%                      .faceArea_median
%   needsRescaling   - true if scale suggests wrong units
%
% Description:
%   Analyzes mesh dimensions to detect inappropriate scale.
%   
%   Heuristics:
%   - Typical brain meshes in meters: vertex extent ~0.1-0.2m, edges ~1-10mm
%   - If in mm: vertex extent ~100-200mm, edges ~1-10mm (still reasonable)
%   - If in μm: vertex extent ~100000-200000μm, edges ~1000-10000μm (extreme)
%
%   Flags as needing rescaling if:
%   - Vertex extent > 10 (likely mm or worse)
%   - Vertex extent < 0.01 (likely μm or worse)
%   - Median edge length > 100 or < 0.0001
%
% See also: bct.manifold.health.check.scale, bct.manifold.metric.rescale

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Requires vertices
if ~mesh.hasV
    scaleStats = struct();
    needsRescaling = false;
    return;
end

V = mesh.V;
F = mesh.F;

% Vertex extent (bounding box)
vertexMin = min(V, [], 1);
vertexMax = max(V, [], 1);
extent = vertexMax - vertexMin;

scaleStats.vertexExtent_min = min(extent);
scaleStats.vertexExtent_max = max(extent);
scaleStats.vertexExtent_range = range(extent);

% Edge lengths
E = mesh.E;
if isempty(E)
    % Derive edges from faces
    E = [F(:,[1,2]); F(:,[2,3]); F(:,[3,1])];
    E = unique(sort(E, 2), 'rows');
end

v1 = V(E(:,1), :);
v2 = V(E(:,2), :);
edgeLengths = sqrt(sum((v2 - v1).^2, 2));

scaleStats.edgeLength_median = median(edgeLengths);
scaleStats.edgeLength_min = min(edgeLengths);
scaleStats.edgeLength_max = max(edgeLengths);

% Face areas (sample if large mesh)
nF = size(F, 1);
if nF > 10000
    % Sample 1000 faces
    sampleIdx = randperm(nF, min(1000, nF));
    F_sample = F(sampleIdx, :);
else
    F_sample = F;
end

v1 = V(F_sample(:,1), :);
v2 = V(F_sample(:,2), :);
v3 = V(F_sample(:,3), :);
faceAreas = 0.5 * sqrt(sum(cross(v2 - v1, v3 - v1, 2).^2, 2));

scaleStats.faceArea_median = median(faceAreas);

% Heuristics for typical brain mesh in meters:
% - Vertex extent: 0.05 - 0.5 m (5cm - 50cm)
% - Median edge length: 0.001 - 0.05 m (1mm - 5cm)
% - Face area: 1e-6 - 1e-3 m² (1mm² - 10cm²)
%
% For unit test meshes (icospheres, etc.):
% - Vertex extent: 0.1 - 10 m is acceptable
% - Edge lengths: 0.0001 - 1 m is acceptable

% Flag if scale seems extreme
needsRescaling = false;

% Too large (likely mm, cm, or worse)
if scaleStats.vertexExtent_max > 10.0 || ...  % > 10 meters extent
   scaleStats.edgeLength_median > 1.0  % > 1m edges
    needsRescaling = true;
end

% Too small (likely μm, nm, or worse)
if scaleStats.vertexExtent_max < 0.001 || ...  % < 1mm extent
   scaleStats.edgeLength_median < 0.00001  % < 0.01mm edges
    needsRescaling = true;
end

end
