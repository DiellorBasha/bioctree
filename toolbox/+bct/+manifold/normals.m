function N = normals(varargin)
%NORMALS Compute vertex or face normals of a triangular mesh
%
% Syntax:
%   N = bct.manifold.normals(M)
%   N = bct.manifold.normals(M, Type)
%   N = bct.manifold.normals(V, F)
%   N = bct.manifold.normals(V, F, Type)
%
% Inputs:
%   M    - bct.Manifold object
%   V    - [N×3] vertex coordinates
%   F    - [M×3] face connectivity (1-indexed)
%   Type - 'Vertex' (default) or 'Face'
%
% Outputs:
%   N - [N×3] vertex normals or [M×3] face normals
%
% Description:
%   Computes vertex or face normals. For Manifold objects, uses cached
%   frames from bct.geometry.frame() for efficiency. For V,F inputs,
%   uses surfaceMesh.computeNormals().
%
% Examples:
%   % Vertex normals from Manifold object (default)
%   M = bct.Manifold(V, F);
%   VN = bct.manifold.normals(M);
%
%   % Face normals from Manifold object
%   FN = bct.manifold.normals(M, 'Face');
%
%   % Vertex normals from V, F directly
%   VN = bct.manifold.normals(V, F);
%
%   % Face normals from V, F directly
%   FN = bct.manifold.normals(V, F, 'Face');
%
%   % Visualize vertex normals
%   VN = bct.manifold.normals(M);
%   quiver3(V(:,1), V(:,2), V(:,3), VN(:,1), VN(:,2), VN(:,3));
%
% See also: bct.geometry.frame, bct.geometry.centroids, bct.geometry.tangents

% Parse inputs
normalType = 'Vertex';  % Default to vertex normals

if nargin == 1
    % Single argument: Manifold object
    if isa(varargin{1}, 'bct.Manifold')
        M = varargin{1};
    else
        error('bct:manifold:normals:InvalidInput', ...
            'Single argument must be a bct.Manifold object');
    end
    
elseif nargin == 2
    if isa(varargin{1}, 'bct.Manifold')
        % M, Type
        M = varargin{1};
        normalType = validateType(varargin{2});
    else
        % V, F (default to vertex normals)
        V = varargin{1};
        F = varargin{2};
        M = [];
    end
    
elseif nargin == 3
    % V, F, Type
    V = varargin{1};
    F = varargin{2};
    normalType = validateType(varargin{3});
    M = [];
    
else
    error('bct:manifold:normals:InvalidNumArgs', ...
        'Expected 1-3 input arguments');
end

% Compute normals
if ~isempty(M)
    % Use cached frames for Manifold objects (efficient)
    fr = bct.geometry.frame(M);
    
    switch normalType
        case 'Vertex'
            N = fr.Vertex.N;
        case 'Face'
            N = fr.Face.N;
        otherwise
            error('bct:manifold:normals:InvalidType', ...
                'Type must be ''Vertex'' or ''Face''');
    end
else
    % For V, F inputs, compute directly using surfaceMesh
    if ~isnumeric(V) || size(V, 2) ~= 3
        error('bct:manifold:normals:InvalidVertices', ...
            'Vertices must be N×3 numeric array');
    end
    if ~isnumeric(F) || size(F, 2) ~= 3
        error('bct:manifold:normals:InvalidFaces', ...
            'Faces must be M×3 numeric array');
    end
    
    mesh = surfaceMesh(V, F);
    
    switch normalType
        case 'Vertex'
            computeNormals(mesh, "vertex");
            N = mesh.VertexNormals;
        case 'Face'
            computeNormals(mesh, "face");
            N = mesh.FaceNormals;
        otherwise
            error('bct:manifold:normals:InvalidType', ...
                'Type must be ''Vertex'' or ''Face''');
    end
end

end

function type = validateType(typeArg)
%VALIDATETYPE Validate and normalize the Type argument

if isstring(typeArg) || ischar(typeArg)
    type = char(typeArg);
    
    % Case-insensitive matching
    switch lower(type)
        case {'vertex', 'v', 'vert', 'vertices'}
            type = 'Vertex';
        case {'face', 'f', 'faces'}
            type = 'Face';
        otherwise
            error('bct:manifold:normals:InvalidType', ...
                'Type must be ''Vertex'' or ''Face'', got ''%s''', type);
    end
else
    error('bct:manifold:normals:InvalidTypeArg', ...
        'Type argument must be a string or char');
end

end
