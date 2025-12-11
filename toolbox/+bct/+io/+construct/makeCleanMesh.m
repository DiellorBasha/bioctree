function mesh = makeCleanMesh(V, F, varargin)
%MAKECLEANMESH Create and clean a surfaceMesh object
%
%   mesh = makeCleanMesh(V, F) creates a surfaceMesh and applies
%   robust cleanup operations
%
%   Options:
%     'Precenter'      - Center mesh at origin (default: false)
%     'RightHandFlip'  - Flip faces for outward normals (default: false)
%     'SkipNormals'    - Skip normal computation (default: false)
%
%   Returns:
%     mesh - Cleaned surfaceMesh object

    % Validate inputs
    validateattributes(V, {'numeric'}, {'2d','ncols',3,'finite','real'}, mfilename, 'V', 1);
    validateattributes(F, {'numeric','integer'}, {'2d','ncols',3,'positive'}, mfilename, 'F', 2);
    
    F = int32(F);
    V = double(V);
    
    % Parse options
    p = inputParser;
    p.FunctionName = mfilename;
    addParameter(p, 'Precenter', false, @(x)islogical(x)&&isscalar(x));
    addParameter(p, 'RightHandFlip', false, @(x)islogical(x)&&isscalar(x));
    addParameter(p, 'SkipNormals', false, @(x)islogical(x)&&isscalar(x));
    parse(p, varargin{:});
    opts = p.Results;
    
    % Apply face flipping if requested
    if opts.RightHandFlip
        F = F(:, [1 3 2]);
    end
    
    % Create surfaceMesh
    mesh = surfaceMesh(V, F);
    
    % Compute normals unless skipped
    if ~opts.SkipNormals
        computeNormals(mesh);
    end
    
    % Center mesh if requested
    if opts.Precenter
        ctr = vertexCenter(mesh);
        translate(mesh, -ctr, ctr);
    end
    
    % Robust cleanup (order matters)
    removeDefects(mesh, "duplicate-vertices");
    removeDefects(mesh, "duplicate-faces");
    removeDefects(mesh, "unreferenced-vertices");
    removeDefects(mesh, "degenerate-faces");
    removeDefects(mesh, "nonmanifold-edges");
end
