function [V2, F2, log] = cleanForDec(V, F, options)
%CLEANFORDEC Clean and orient a triangle mesh for DEC using surfaceMesh + custom orientation.
%
% Usage:
%   [V2, F2, log] = bct.manifold.health.repair.cleanForDEC(V, F);
%
% Outputs:
%   V2, F2 : repaired mesh
%   log    : struct with steps, flags, and counts for debugging/GUI
%
% Notes:
%   - Orientation consistency (local winding) is required for DEC.
%   - "Outward" is only meaningful if watertight (closed).
%
arguments
    V double
    F double
    options.ExpectWatertight (1,1) logical = false
    options.AllowBoundaryEdges (1,1) logical = true
    options.FixNonmanifoldEdges (1,1) logical = true
    options.FixSelfIntersections (1,1) logical = false % surfaceMesh doesn't generally fix these; kept for policy.
    options.Verbose (1,1) logical = true
end

log = struct();
log.input.nV = size(V,1);
log.input.nF = size(F,1);

% ---------- Stage A: surfaceMesh removeDefects ----------
mesh = surfaceMesh(V, F);

steps = ["duplicate-vertices", "unreferenced-vertices", "duplicate-faces", "degenerate-faces"];
if options.FixNonmanifoldEdges
    steps(end+1) = "nonmanifold-edges";
end

log.defects = struct();
for s = steps
    try
        removeDefects(mesh, s);
        log.defects.(matlab.lang.makeValidName(s)) = "ok";
    catch ME
        log.defects.(matlab.lang.makeValidName(s)) = "failed: " + string(ME.message);
        % Do not hard error here; continue to extract what we can.
    end
end

mesh.computeNormals();

% Extract mesh after defect removal
Vw = mesh.Vertices;
Fw = mesh.Faces;

log.afterDefects.nV = size(Vw,1);
log.afterDefects.nF = size(Fw,1);

% ---------- Stage B: enforce consistent winding ----------
[Fw2, orientInfo] = bct.manifold.health.repair.orientConsistently(Vw, Fw);
log.orientConsistently = orientInfo;

% ---------- Stage C: enforce outward if watertight ----------
mesh2 = surfaceMesh(Vw, Fw2);
isWT = isWatertight(mesh2);
log.validation.isWatertight_beforeOutward = isWT;

if options.ExpectWatertight && ~isWT
    log.validation.watertightError = "Expected watertight mesh but surfaceMesh reports not watertight.";
end

if isWT
    [Fw3, outInfo] = bct.manifold.health.repair.orientOutward(Vw, Fw2);
    log.orientOutward = outInfo;
else
    Fw3 = Fw2;
    log.orientOutward = struct('applied', false, 'reason', "not watertight (outward not well-defined)");
end

% ---------- Stage D: final validation ----------
mesh3 = surfaceMesh(Vw, Fw3);
mesh3.computeNormals();

log.validation.isEdgeManifold = isEdgeManifold(mesh3, options.AllowBoundaryEdges);
log.validation.isOrientable   = isOrientable(mesh3);
log.validation.isVertexManifold = isVertexManifold(mesh3);
log.validation.isWatertight   = isWatertight(mesh3);
log.validation.isSelfIntersecting = isSelfIntersecting(mesh3);

% Policy checks
log.policy.okForDEC = log.validation.isOrientable && log.validation.isEdgeManifold && log.validation.isVertexManifold;
if options.ExpectWatertight
    log.policy.okForDEC = log.policy.okForDEC && log.validation.isWatertight;
end

V2 = Vw;
F2 = Fw3;

log.output.nV = size(V2,1);
log.output.nF = size(F2,1);

end
