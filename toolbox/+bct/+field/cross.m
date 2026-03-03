function crossField = cross(M, directionField, varargin)
%CROSS Compute cross field from direction field on manifold
%
% Syntax:
%   crossField = bct.field.cross(M, directionField)
%   crossField = bct.field.cross(M, directionField, 'Format', 'struct')
%
% Inputs:
%   M              - bct.Manifold object
%   directionField - Direction field as either:
%                    - bct.Field object with support='face', valueType='vector3'
%                    - [nF×3] matrix of face-tangent direction vectors
%
% Optional Parameters:
%   'Format' - Output format:
%              'struct' (default) - Returns struct with fields d1, d2, d3, d4
%              'array'            - Returns [nF×4×3] array
%              'cell'             - Returns {d1, d2, d3, d4} cell array
%
% Outputs:
%   crossField - Cross field representation (4 perpendicular directions per face)
%                Format depends on 'Format' parameter:
%                - struct: .d1, .d2, .d3, .d4 each [nF×3]
%                - array: [nF×4×3] with crossField(f,k,:) = kth direction at face f
%                - cell: {d1, d2, d3, d4} where each is [nF×3]
%
% Description:
%   Computes a cross field from a direction field by generating 4 perpendicular
%   directions in the tangent plane of each face. For a given direction d at face f
%   with normal n:
%   
%   d1 = d              (original direction)
%   d2 = n × d          (perpendicular in tangent plane, 90° rotation)
%   d3 = -d             (opposite direction, 180° rotation)
%   d4 = d × n          (perpendicular, 270° rotation)
%   
%   These 4 directions form a cross pattern in the local tangent plane,
%   commonly used in:
%   - Quadrilateral mesh generation
%   - Texture synthesis on surfaces
%   - Principal curvature direction fields
%   - Anisotropic surface processing
%
% Examples:
%   % Compute cross field from direction field
%   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
%   
%   % Create direction field
%   dirField = computeDirectionField(M);  % Your direction field
%   
%   % Generate cross field
%   cross = bct.field.cross(M, dirField);
%   
%   % Visualize efficiently using addCross (recommended)
%   viewer = bct.ui.show(M);
%   viewer.addCross(cross, 'Scale', 3, 'Color', 0x000000);
%   
%   % Or access individual directions for custom visualization
%   d1 = cross.d1;  % [nF×3] original direction
%   d2 = cross.d2;  % [nF×3] perpendicular (90°)
%   d3 = cross.d3;  % [nF×3] opposite (180°)
%   d4 = cross.d4;  % [nF×3] perpendicular (270°)
%   
%   % Visualize all 4 directions separately (less efficient)
%   viewer.addVector(cross.d1, 'Color', 0xff0000, 'Scale', 5);
%   viewer.addVector(cross.d2, 'Color', 0x00ff00, 'Scale', 5);
%   viewer.addVector(cross.d3, 'Color', 0x0000ff, 'Scale', 5);
%   viewer.addVector(cross.d4, 'Color', 0xffff00, 'Scale', 5);
%   
%   % Get as array format
%   crossArray = bct.field.cross(M, dirField, 'Format', 'array');
%   % crossArray(f, :, :) gives all 4 directions at face f
%
% Notes:
%   - Input direction field must be tangent to face planes
%   - Cross field directions are automatically normalized
%   - All 4 directions lie in the tangent plane (perpendicular to normal)
%   - Direction order follows right-hand rule around face normal
%   - Use viewer.addCross() for efficient visualization
%
% See also: bct.field.streamline, bct.manifold.connection.trivial, bct.ui.manifold.Viewer.addCross

% Input validation
arguments
    M (1,1) {mustBeA(M, 'bct.Manifold')}
    directionField
end

arguments (Repeating)
    varargin
end

% Parse optional parameters
p = inputParser();
p.addParameter('Format', 'struct', @(x) ismember(x, {'struct', 'array', 'cell'}));
p.parse(varargin{:});

opts = p.Results;

% Get number of faces
nF = M.numFaces();

% Parse direction field input
if isa(directionField, 'bct.Field')
    % Field object - extract values and validate
    if directionField.support ~= "face"
        error('bct:field:cross:InvalidSupport', ...
            'Direction field must have support="face", got "%s"', directionField.support);
    end
    if ~ismember(directionField.valueType, ["vector3", "tangent2"])
        error('bct:field:cross:InvalidValueType', ...
            'Direction field must have valueType="vector3" or "tangent2", got "%s"', ...
            directionField.valueType);
    end
    
    % If tangent2, convert to vector3 using tangent frames
    if directionField.valueType == "tangent2"
        % Get tangent frames
        geom = M.geometry();
        T1 = geom.face.tangent1.value;  % [nF×3]
        T2 = geom.face.tangent2.value;  % [nF×3]
        
        % Convert: d = a*t1 + b*t2
        a = directionField.value(:, 1);
        b = directionField.value(:, 2);
        d = a .* T1 + b .* T2;
    else
        d = directionField.value;
    end
elseif isnumeric(directionField)
    % Numeric matrix
    if size(directionField, 1) ~= nF || size(directionField, 2) ~= 3
        error('bct:field:cross:InvalidSize', ...
            'Direction field must be [nF×3], got [%d×%d]', ...
            size(directionField, 1), size(directionField, 2));
    end
    d = directionField;
else
    error('bct:field:cross:InvalidInput', ...
        'Direction field must be bct.Field object or [nF×3] matrix');
end

% Get face normals
geom = M.geometry();
n = geom.face.normals.value;  % [nF×3] unit normals

% Compute 4 perpendicular directions
% d1 = d (original direction)
d1 = d;

% d2 = n × d (perpendicular, 90° rotation in tangent plane)
d2 = cross(n, d, 2);

% d3 = -d (opposite direction, 180° rotation)
d3 = -d;

% d4 = d × n (perpendicular, 270° rotation)
d4 = cross(d, n, 2);

% Normalize all directions
d1 = normalizeRows_(d1);
d2 = normalizeRows_(d2);
d3 = normalizeRows_(d3);
d4 = normalizeRows_(d4);

% Verify input direction field is tangent to surface (optional check)
maxDot = max(abs(sum(d1 .* n, 2)));
if maxDot > 1e-3
    warning('bct:field:cross:NotTangent', ...
        'Input direction field may not be tangent to surface (max dot product with normal: %.6f)', ...
        maxDot);
end

% Format output according to requested format
switch opts.Format
    case 'struct'
        crossField = struct();
        crossField.d1 = d1;
        crossField.d2 = d2;
        crossField.d3 = d3;
        crossField.d4 = d4;
        crossField.format = 'struct';
        crossField.description = 'Cross field: 4 perpendicular directions per face';
        
    case 'array'
        % Stack into [nF×4×3] array
        crossField = zeros(nF, 4, 3);
        crossField(:, 1, :) = d1;
        crossField(:, 2, :) = d2;
        crossField(:, 3, :) = d3;
        crossField(:, 4, :) = d4;
        
    case 'cell'
        crossField = {d1, d2, d3, d4};
end

end


%% Helper Functions

function vn = normalizeRows_(v)
%NORMALIZEROWS_ Normalize each row of a matrix to unit length
%
% Input:
%   v - [N×3] matrix of vectors
%
% Output:
%   vn - [N×3] matrix of normalized vectors

norms = sqrt(sum(v.^2, 2));
norms = max(norms, 1e-12);  % Avoid division by zero
vn = v ./ norms;

end
