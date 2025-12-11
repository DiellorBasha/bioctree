function B = mesh(V, F, opts)
%MESH Construct bct object with mesh-type Manifold
%
%   B = bct.io.construct.mesh(V, F) creates a bct object with
%   mesh-type Manifold from vertices and faces
%
%   Inputs:
%     V - Nx3 vertices
%     F - Mx3 faces
%
%   Options:
%     Precenter      - Center mesh before construction (default: true)
%     RightHandFlip  - Flip for outward normals (default: true)
%     SkipNormals    - Skip normal computation (default: false)
%
%   Returns:
%     B - bct object with mesh-type Manifold
%
%   See also: bct.io.construct.graph

    if nargin < 3
        opts = struct();
    end
    
    % Set defaults
    if ~isfield(opts, 'Precenter'), opts.Precenter = true; end
    if ~isfield(opts, 'RightHandFlip'), opts.RightHandFlip = true; end
    if ~isfield(opts, 'SkipNormals'), opts.SkipNormals = false; end
    
    % Ensure correct face orientation for outward normals
    if opts.RightHandFlip && ~isempty(F)
        F = F(:, [1 3 2]);
    end
    
    % Clean and validate mesh
    cleanMesh = bct.io.construct.makeCleanMesh(V, F, ...
        'Precenter', opts.Precenter, ...
        'RightHandFlip', false, ...  % Already flipped above
        'SkipNormals', opts.SkipNormals);
    
    % Use bct.fromMesh factory method which creates Manifold and Lambda with dual linking
    B = bct.bct.fromMesh(cleanMesh.Vertices, cleanMesh.Faces);
end
