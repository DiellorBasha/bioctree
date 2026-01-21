function out = vertex(meshInput, varargin)
%VERTEX Compute all vertex-based geometric properties
%
% Syntax:
%   vertexGeom = bct.manifold.geometry.vertex(M)
%   vertexGeom = bct.manifold.geometry.vertex(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   out - Structure matching bct.manifold.geometry.vertex.schema:
%     .attributes - Group-level metadata (computation method, frame convention)
%     .normals    - [Nv×3] Vertex normal vectors (unit, area-weighted)
%     .tangent1   - [Nv×3] First tangent vectors (unit, orthogonal to normals)
%     .tangent2   - [Nv×3] Second tangent vectors (unit, orthogonal to normals and tangent1)
%
% Description:
%   Aggregator function that computes all vertex-based geometric properties
%   by calling bct.manifold.geometry.vertex.frame().
%
%   Output structure conforms to bct.manifold.geometry.vertex.schema for
%   seamless serialization to HDF5/Zarr formats.
%
% Examples:
%   % Compute all vertex geometry
%   M = bct.Manifold(V, F);
%   vg = bct.manifold.geometry.vertex(M);
%   
%   % Access datasets
%   normals = vg.normals;
%   tangent1 = vg.tangent1;
%   tangent2 = vg.tangent2;
%   
%   % Access group attributes
%   frameConvention = vg.attributes.frame_convention;
%   
%   % Validate against schema
%   s = bct.manifold.geometry.vertex.schema();
%   [isValid, report] = bct.manifold.geometry.vertex.validateSchema(vg, s);
%
% See also: bct.manifold.geometry.vertex.schema, bct.manifold.geometry.face,
%           bct.manifold.geometry.edge, bct.manifold.geometry

% Parse inputs
if nargin == 0
    error('bct:manifold:geometry:vertex:NoInput', ...
        'At least one input required: vertex(M) or vertex(V, F)');
end

% Validate input (Manifold or V,F)
if isa(meshInput, 'bct.Manifold')
    % vertex(M)
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % vertex(V, F) - valid
    V = meshInput;
    F = varargin{1};
else
    error('bct:manifold:geometry:vertex:InvalidInput', ...
        'Expected vertex(M) or vertex(V, F)');
end

% Create surfaceMesh once to avoid redundant creation in subfunctions
mesh = surfaceMesh(V, F);

% Compute vertex frame (normals + tangents) in one call
[frameHeader, normals, tangent1, tangent2] = ...
    bct.manifold.geometry.vertex.frame(mesh);

% Initialize output structure matching schema
out = struct();

% Group-level attributes (matches s.group.attributes in schema)
out.attributes = struct();
out.attributes.schema = 'bct.manifold.geometry.vertex@1.0.0';
out.attributes.package = 'bct.manifold.geometry.vertex';
out.attributes.frame_handedness = 'right-handed';
out.attributes.frame_convention = 'tangent2 = normal × tangent1';
out.attributes.normal_weighting = 'area-weighted';
out.attributes.tangent_method = 'reference_axis_projection';
out.attributes.computation_method = frameHeader.method;  % From frame computation
out.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% Dataset fields (matches s.datasets in schema)
% Order matches schema dataset order for consistent serialization
out.normals = normals;      % Dataset 1
out.tangent1 = tangent1;    % Dataset 2
out.tangent2 = tangent2;    % Dataset 3

end
