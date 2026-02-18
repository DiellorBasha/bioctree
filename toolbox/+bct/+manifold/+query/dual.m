function out = dual(meshInput, stepVal, varargin)
%DUAL Breadth-first traversal on dual (face adjacency) graph
%
% Syntax:
%   out = bct.manifold.query.dual(M, stepVal)
%   out = bct.manifold.query.dual(M, stepVal, 'seedFace', f0)
%   out = bct.manifold.query.dual(FH, faceH, twinH, stepVal, ...)
%
% Purpose:
%   Propagates a face scalar potential alpha_face from a seed face by 
%   crossing halfedges and adding a per-halfedge increment stepVal(h):
%
%     alpha_face(fj) = alpha_face(fi) + stepVal(h)
%
%   where fj is the face across twin(h): fj = faceH(twinH(h)).
%
%   This is useful for building direction fields where alpha represents
%   angles in each face's tangent frame, and stepVal(h) represents the
%   rotation when crossing an edge (e.g., from bct.manifold.connection.transport).
%
% Inputs:
%   Mode 1: Manifold input
%     M       - bct.Manifold object
%     stepVal - [nH×1] increment attached to each halfedge
%
%   Mode 2: Direct topology input
%     FH      - [nF×3] Face halfedges (halfedges around each face)
%     faceH   - [nH×1] Face index for each halfedge (owner face)
%     twinH   - [nH×1] Twin halfedge index (0 if none)
%     stepVal - [nH×1] Increment attached to each halfedge
%
% Name-Value Arguments:
%   'seedFace'  - Seed face index (default: 1)
%   'seedValue' - Alpha value at seed face (default: 0)
%   'validH'    - [nH×1] logical validity mask (default: auto-detect from twin/face)
%   'wrap'      - If true, wrap alpha to (-π,π] at end (default: false)
%
% Outputs:
%   out - Structure with fields:
%     .alpha_face      - [nF×1] Face scalar values (NaN for unreachable)
%     .parentFace      - [nF×1] Parent face in BFS tree (0 for seed/unreached)
%     .parentHalfedge  - [nF×1] Parent halfedge in BFS tree (0 for seed/unreached)
%     .order           - [nVisited×1] BFS visitation order (face indices)
%
% Notes:
%   - This is NOT shortest-path with weights; it's a spanning-tree propagation
%   - For closed manifolds (sphere), all faces should be reached from any seed
%   - Useful for building direction fields on surfaces
%
% Examples:
%   % Propagate direction field using connection transport
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   conn = M.connection('trivial', 'singularities', [100, 500], 'weights', [1, 1]);
%   trans = bct.manifold.connection.transport(M, conn);
%   
%   % Build direction field by propagating from seed face
%   result = bct.manifold.query.dual(M, trans.combinedTransport.value, ...
%       'seedFace', 1, 'seedValue', 0, 'wrap', true);
%   alpha = result.alpha_face;  % Direction angle in each face
%
%   % Direct topology input
%   topo = M.topology();
%   FH = topo.faceHalfedges.value;
%   faceH = topo.face.value;
%   twinH = topo.twin.value;
%   result = bct.manifold.query.dual(FH, faceH, twinH, stepVal);
%
% See also: bct.manifold.connection.transport, bct.manifold.query.bfSearch

% Parse inputs - check for Manifold object vs direct topology
if isa(meshInput, 'bct.Manifold')
    % Mode 1: Manifold input
    M = meshInput;
    topo = M.topology();
    
    FH = topo.faceHalfedges.value;     % [nF×3]
    faceH = topo.face.value;           % [nH×1]
    twinH = topo.twin.value;           % [nH×1]
    
    % stepVal is second argument
    if nargin < 2
        error('bct:manifold:query:dual:MissingStepVal', ...
            'stepVal required as second argument');
    end
    
    extraArgs = varargin;
    
elseif isnumeric(meshInput) && nargin >= 4
    % Mode 2: Direct topology input (FH, faceH, twinH, stepVal, ...)
    FH = meshInput;
    faceH = stepVal;      % Actually the second positional arg
    twinH = varargin{1};  % Third positional arg
    stepVal = varargin{2}; % Fourth positional arg
    
    if nargin > 4
        extraArgs = varargin(3:end);
    else
        extraArgs = {};
    end
    
else
    error('bct:manifold:query:dual:InvalidInput', ...
        'Expected dual(M, stepVal, ...) or dual(FH, faceH, twinH, stepVal, ...)');
end

% Parse options
p = inputParser;
p.FunctionName = 'bct.manifold.query.dual';
addParameter(p, 'seedFace', uint32(1), @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'seedValue', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'validH', [], @(x) isempty(x) || islogical(x));
addParameter(p, 'wrap', false, @islogical);
parse(p, extraArgs{:});

seedFace = uint32(p.Results.seedFace);
seedValue = p.Results.seedValue;
validH = p.Results.validH;
doWrap = p.Results.wrap;

% Get dimensions
nF = size(FH, 1);
nH = numel(faceH);

% Validate inputs
if size(FH, 2) ~= 3
    error('bct:manifold:query:dual:InvalidFH', ...
        'FH must be [nF×3] array');
end
if numel(twinH) ~= nH
    error('bct:manifold:query:dual:DimensionMismatch', ...
        'twinH must have same length as faceH');
end
if numel(stepVal) ~= nH
    error('bct:manifold:query:dual:DimensionMismatch', ...
        'stepVal must have same length as faceH');
end
if seedFace < 1 || seedFace > nF
    error('bct:manifold:query:dual:InvalidSeedFace', ...
        'seedFace must be in range [1, %d]', nF);
end

% Construct validity mask
if isempty(validH)
    % Valid if twin exists and has a valid face index
    validH = (twinH > 0);
    % Also require the opposite face to exist
    idx = twinH(validH);
    validH(validH) = (faceH(idx) > 0);
else
    if numel(validH) ~= nH
        error('bct:manifold:query:dual:InvalidValidH', ...
            'validH must have length nH = %d', nH);
    end
end

% Allocate outputs
alpha_face = nan(nF, 1);
visited = false(nF, 1);

parentFace = zeros(nF, 1, 'uint32');
parentHalfedge = zeros(nF, 1, 'uint32');

% BFS queue (uint32)
Q = zeros(nF, 1, 'uint32');
qh = 1; 
qt = 1;
Q(qt) = seedFace;

alpha_face(seedFace) = seedValue;
visited(seedFace) = true;

% Visitation order
order = zeros(nF, 1, 'uint32');
kord = 0;

% BFS traversal
while qh <= qt
    fi = Q(qh); 
    qh = qh + 1;

    kord = kord + 1;
    order(kord) = fi;

    hs = FH(fi, :);  % [1×3] halfedges around face fi
    for kk = 1:3
        h = hs(kk);
        if h == 0 || ~validH(h)
            continue;
        end

        ht = twinH(h);
        if ht == 0
            continue;
        end

        fj = faceH(ht);
        if fj == 0
            continue;
        end

        if ~visited(fj)
            visited(fj) = true;
            alpha_face(fj) = alpha_face(fi) + stepVal(h);

            parentFace(fj) = fi;
            parentHalfedge(fj) = h;

            qt = qt + 1;
            Q(qt) = fj;
        end
    end
end

% Trim order to actual visited count
order = order(1:kord);

% Optional wrapping to (-π, π]
if doWrap
    alpha_face = mod(alpha_face + pi, 2*pi) - pi;
end

% Build output structure
out = struct();
out.alpha_face = alpha_face;
out.parentFace = parentFace;
out.parentHalfedge = parentHalfedge;
out.order = order;

end
