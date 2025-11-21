function B = graph(V, F, opts)
%GRAPH Construct bct object with graph-type Manifold
%
%   B = bct.io.construct.graph(V, F) creates a bct object with
%   graph-type Manifold from vertices and faces (edges extracted)
%
%   Inputs:
%     V - Nx3 vertices
%     F - Mx3 faces (edges will be extracted)
%
%   Options:
%     Precenter      - Center mesh before construction (default: true)
%     RightHandFlip  - Flip for outward normals (default: true)
%     SkipNormals    - Skip normal computation (default: false)
%
%   Returns:
%     B - bct object with graph-type Manifold
%
%   See also: bct.io.construct.mesh

    if nargin < 3
        opts = struct();
    end
    
    % Set defaults
    if ~isfield(opts, 'Precenter'), opts.Precenter = true; end
    if ~isfield(opts, 'RightHandFlip'), opts.RightHandFlip = true; end
    if ~isfield(opts, 'SkipNormals'), opts.SkipNormals = false; end
    
    % Ensure correct face orientation
    if opts.RightHandFlip && ~isempty(F)
        F = F(:, [1 3 2]);
    end
    
    % Clean and validate mesh
    cleanMesh = bct.io.construct.makeCleanMesh(V, F, ...
        'Precenter', opts.Precenter, ...
        'RightHandFlip', false, ...  % Already flipped
        'SkipNormals', opts.SkipNormals);
    
    % Extract edges from faces
    E = bct.io.construct.edgesFromFaces(cleanMesh.Faces);
    
    % Build adjacency matrix from edges
    N = size(cleanMesh.Vertices, 1);
    A = sparse(E(:,1), E(:,2), true, N, N);
    A = A + A.';  % Make symmetric
    A = A - diag(diag(A));  % Remove self-loops
    
    % Use bct.fromAdjacency factory method with coordinates
    B = bct.bct.fromAdjacency(A, cleanMesh.Vertices);
end
