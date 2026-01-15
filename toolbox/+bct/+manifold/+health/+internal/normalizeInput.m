function mesh = normalizeInput(varargin)
%NORMALIZEINPUT Parse and validate input for health checks
%
% Syntax:
%   mesh = bct.manifold.health.internal.normalizeInput(M)
%   mesh = bct.manifold.health.internal.normalizeInput(surfMesh)
%   mesh = bct.manifold.health.internal.normalizeInput(F)
%   mesh = bct.manifold.health.internal.normalizeInput(V, F)
%   mesh = bct.manifold.health.internal.normalizeInput({V, F})
%
% Inputs:
%   M        - bct.Manifold object (primary, preferred input)
%   surfMesh - surfaceMesh object (optimization path)
%   F        - [nF×3] face connectivity matrix
%   V        - [nV×3] vertex coordinates
%   {V, F}   - cell array with vertices and faces
%
% Outputs:
%   mesh - Structure with fields:
%     .isManifoldObj - true if input was bct.Manifold, false otherwise
%     .M             - bct.Manifold object (or empty)
%     .V             - vertex coordinates (empty if not provided)
%     .F             - face connectivity
%     .E             - canonical edge list (set by ensureCanonicalEdges)
%     .nV            - number of vertices
%     .nF            - number of faces
%     .nE            - number of edges (set by ensureCanonicalEdges)
%     .hasV          - logical, true if V was provided
%     .source        - "Manifold" | "VF" | "F"
%
% Description:
%   Normalizes various input formats into a standard mesh structure.
%   Primary target is bct.Manifold, with fallbacks for {V,F} and F-only.
%
%   Edge list E is NOT populated here; use ensureCanonicalEdges() after
%   this call to establish canonical edge index space.
%
% See also: bct.manifold.health.check, bct.manifold.health.internal.ensureCanonicalEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Initialize
isManifoldObj = false;
M = [];
V = [];
F = [];
hasV = false;
source = "F";

% Parse inputs
if nargin == 0
    error('bct:manifold:health:normalizeInput:NoInput', ...
        'At least one input argument required');
        
elseif nargin == 1
    arg = varargin{1};
    
    if isa(arg, 'bct.Manifold')
        % Primary path: Manifold object
        isManifoldObj = true;
        M = arg;
        V = arg.Vertices;
        F = arg.Faces;
        hasV = true;
        source = "Manifold";
        
    elseif isa(arg, 'surfaceMesh')
        % Optimization path: surfaceMesh object (avoid redundant creation)
        V = arg.Vertices;
        F = arg.Faces;
        hasV = true;
        source = "surfaceMesh";
        
    elseif iscell(arg) && numel(arg) == 2
        % Fallback: {V, F} cell array
        V = arg{1};
        F = arg{2};
        hasV = true;
        source = "VF";
        
    elseif isnumeric(arg) && size(arg, 2) == 3
        % Fallback: F only
        F = arg;
        hasV = false;
        source = "F";
        
    else
        error('bct:manifold:health:normalizeInput:InvalidInput', ...
            'Single input must be bct.Manifold, surfaceMesh, {V,F} cell, or F matrix');
    end
    
elseif nargin == 2
    % Fallback: V, F separate arguments
    V = varargin{1};
    F = varargin{2};
    hasV = true;
    source = "VF";
    
else
    error('bct:manifold:health:normalizeInput:TooManyInputs', ...
        'Expected 1 or 2 inputs');
end

% Validate F
if isempty(F)
    nF = 0;
    nV = 0;
elseif ~isnumeric(F) || size(F, 2) ~= 3
    error('bct:manifold:health:normalizeInput:InvalidFaces', ...
        'Faces must be numeric nF×3 matrix');
else
    nF = size(F, 1);
    
    % Determine nV
    if hasV && ~isempty(V)
        if ~isnumeric(V) || size(V, 2) < 3
            error('bct:manifold:health:normalizeInput:InvalidVertices', ...
                'Vertices must be numeric nV×3 (or nV×d) matrix');
        end
        nV = size(V, 1);
    else
        % Infer from F
        if nF > 0
            nV = max(F(:));
        else
            nV = 0;
        end
        V = [];
        hasV = false;
    end
end

% Build output struct (E and nE set by ensureCanonicalEdges)
mesh = struct( ...
    'isManifoldObj', isManifoldObj, ...
    'M', M, ...
    'V', V, ...
    'F', F, ...
    'E', [], ...
    'nV', nV, ...
    'nF', nF, ...
    'nE', 0, ...
    'hasV', hasV, ...
    'source', source ...
);

% Add adjacency if from Manifold object (for connectivity check)
if isManifoldObj && ~isempty(M)
    mesh.adjacency = M.adjacency();
else
    mesh.adjacency = [];
end

end
