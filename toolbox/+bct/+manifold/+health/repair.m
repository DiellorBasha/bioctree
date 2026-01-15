function varargout = repair(meshInput, defectTypeOrReport, varargin)
%REPAIR Repair mesh defects using modular repair functions
%
% Syntax:
%   M_repaired = bct.manifold.health.repair(M, defectType)
%   M_repaired = bct.manifold.health.repair(M, healthReport)
%   M_repaired = bct.manifold.health.repair(M, defectType, Name=Value)
%   [V_repaired, F_repaired] = bct.manifold.health.repair(V, F, defectType)
%
% Inputs:
%   M              - bct.Manifold object
%   OR
%   V              - [N×3] vertex coordinates
%   F              - [M×3] face connectivity
%   defectType     - String specifying repair type:
%                    "unreferenced-vertices" | "duplicate-vertices" |
%                    "duplicate-faces" | "degenerate-faces" |
%                    "nonmanifold-edges"
%   healthReport   - Health report struct from M.health()
%                    Automatically applies repairs for detected issues
%
% Outputs:
%   M_repaired - Repaired bct.Manifold (if Manifold input)
%   OR
%   V_repaired, F_repaired - Repaired mesh arrays (if V,F input)
%
% Examples:
%   % Repair specific defect
%   M_clean = bct.manifold.health.repair(M, "unreferenced-vertices");
%
%   % Repair all issues from health report
%   h = M.health();
%   M_clean = bct.manifold.health.repair(M, h);
%
%   % Repair V,F arrays
%   [V_clean, F_clean] = bct.manifold.health.repair(V, F, "duplicate-faces");
%
%   % Chain repairs
%   M = bct.manifold.health.repair(M, "unreferenced-vertices");
%   M = bct.manifold.health.repair(M, "nonmanifold-edges");
%
% See also: bct.manifold.health.check, surfaceMesh.removeDefects

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse input - determine if Manifold or (V,F)
if isa(meshInput, 'bct.Manifold')
    % Manifold input
    isManifoldInput = true;
    V = meshInput.Vertices;
    F = meshInput.Faces;
    
    % Check if second arg is health report or defect type
    if isstruct(defectTypeOrReport) && isfield(defectTypeOrReport, 'issues')
        % Health report - extract defects and apply repairs
        [V, F] = applyHealthReportRepairs(V, F, defectTypeOrReport);
        
        % Return repaired Manifold
        varargout{1} = bct.Manifold(V, F);
        return;
    else
        defect = defectTypeOrReport;
    end
    
elseif isnumeric(meshInput) && nargin >= 3
    % (V,F) input
    isManifoldInput = false;
    V = meshInput;
    F = defectTypeOrReport;
    defect = varargin{1};
    varargin = varargin(2:end);
    
else
    error('bct:manifold:health:repair:InvalidInput', ...
        'Expected repair(M, defectType), repair(M, healthReport), or repair(V, F, defectType)');
end

% Validate defectType
validDefects = ["unreferenced-vertices", "duplicate-vertices", ...
                "duplicate-faces", "degenerate-faces", "nonmanifold-edges"];
if ~ismember(defect, validDefects)
    error('bct:manifold:health:repair:InvalidDefect', ...
        'Invalid defect type "%s". Valid types: %s', ...
        defect, strjoin(validDefects, ', '));
end

% Dispatch to specific repair function
switch defect
    case "unreferenced-vertices"
        [V_out, F_out] = bct.manifold.health.repair.unreferencedVertices(V, F);
        
    case "duplicate-vertices"
        [V_out, F_out] = bct.manifold.health.repair.duplicateVertices(V, F);
        
    case "duplicate-faces"
        [V_out, F_out] = bct.manifold.health.repair.duplicateFaces(V, F);
        
    case "degenerate-faces"
        [V_out, F_out] = bct.manifold.health.repair.degenerateFaces(V, F);
        
    case "nonmanifold-edges"
        [V_out, F_out] = bct.manifold.health.repair.nonManifoldEdges(V, F);
end

% Return appropriate output format
if isManifoldInput
    % Return Manifold
    varargout{1} = bct.Manifold(V_out, F_out);
else
    % Return V, F
    varargout{1} = V_out;
    varargout{2} = F_out;
end

end

% =========================================================================
% Helper Functions
% =========================================================================

function [V_out, F_out] = applyHealthReportRepairs(V, F, healthReport)
%APPLYHEALTHREPORTREPAIRS Apply repairs based on health report issues

% Map health check issue IDs to repair defect types
issueToRepairMap = containers.Map(...
    {'degenerateFaces', 'duplicateFaces', 'duplicateDirectedEdges', 'nonManifoldEdges'}, ...
    {'degenerate-faces', 'duplicate-faces', 'duplicate-vertices', 'nonmanifold-edges'});

% Extract issues
issues = healthReport.issues;

% Collect unique repair types needed
repairsNeeded = string.empty;
needsOrientationFix = false;
needsFlip = false;

for i = 1:length(issues)
    issueId = issues(i).id;
    
    % Map issue to repair if mapping exists
    if isKey(issueToRepairMap, char(issueId))
        repairType = issueToRepairMap(char(issueId));
        if ~ismember(repairType, repairsNeeded)
            repairsNeeded(end+1) = repairType; %#ok<AGROW>
        end
    end
    
    % Check for orientation issues
    if issueId == "orientationInconsistent"
        needsOrientationFix = true;
    elseif issueId == "inwardOrientation"
        needsFlip = true;
    end
end

% Apply repairs in recommended order
repairOrder = ["duplicate-vertices", "unreferenced-vertices", ...
               "duplicate-faces", "degenerate-faces", "nonmanifold-edges"];

V_out = V;
F_out = F;

for i = 1:length(repairOrder)
    repairType = repairOrder(i);
    if ismember(repairType, repairsNeeded)
        fprintf('Applying repair: %s\n', repairType);
        
        % Apply specific repair
        switch repairType
            case "unreferenced-vertices"
                [V_out, F_out] = bct.manifold.health.repair.unreferencedVertices(V_out, F_out);
            case "duplicate-vertices"
                [V_out, F_out] = bct.manifold.health.repair.duplicateVertices(V_out, F_out);
            case "duplicate-faces"
                [V_out, F_out] = bct.manifold.health.repair.duplicateFaces(V_out, F_out);
            case "degenerate-faces"
                [V_out, F_out] = bct.manifold.health.repair.degenerateFaces(V_out, F_out);
            case "nonmanifold-edges"
                [V_out, F_out] = bct.manifold.health.repair.nonManifoldEdges(V_out, F_out);
        end
    end
end

% Always clean up unreferenced vertices at the end (in case nonmanifold repair created some)
if ismember("nonmanifold-edges", repairsNeeded)
    fprintf('Applying cleanup: unreferenced-vertices\n');
    [V_out, F_out] = bct.manifold.health.repair.unreferencedVertices(V_out, F_out);
end

% Fix orientation consistency if needed
if needsOrientationFix
    fprintf('Applying repair: orientation-consistency\n');
    [F_out, ~] = bct.manifold.health.repair.orientConsistently(V_out, F_out);
end

% Flip faces if inward orientation detected
if needsFlip
    fprintf('Applying repair: flip (inward orientation)\n');
    [~, F_out] = bct.manifold.geometry.face.flip(V_out, F_out);
end

end
