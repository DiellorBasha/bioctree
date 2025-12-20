function obj = out(M, targetType)
%OUT Convert bct.Manifold to MATLAB geometry object
%
% Syntax:
%   obj = bct.manifold.out(M, 'surfaceMesh')
%   obj = bct.manifold.out(M, 'triangulation')
%   obj = bct.manifold.out(M, 'patch')
%
% Supported Target Types:
%   - 'surfaceMesh': Creates MATLAB surfaceMesh object
%   - 'triangulation': Creates MATLAB triangulation object
%   - 'patch': Creates MATLAB Patch graphics object (in invisible figure)
%
% Inputs:
%   M          - bct.Manifold object
%   targetType - String specifying target geometry type
%
% Outputs:
%   obj - Geometry object of specified type
%
% Notes:
%   - Faces are automatically converted to double for compatibility
%   - Patch objects are created in an invisible figure by default
%   - For patch objects with visible figures, use patch() directly
%
% Examples:
%   % Convert to surfaceMesh
%   M = bct.Manifold(V, F);
%   smesh = bct.manifold.out(M, 'surfaceMesh');
%
%   % Convert to triangulation
%   tri = bct.manifold.out(M, 'triangulation');
%
%   % Convert to patch (in invisible figure)
%   p = bct.manifold.out(M, 'patch');
%
% See also: bct.Manifold, bct.manifold.in, bct.manifold.convert

arguments
    M          bct.Manifold
    targetType (1,1) string {mustBeMember(targetType, ["surfaceMesh", "triangulation", "patch"])}
end

% Get vertices and faces from Manifold
V = M.Vertices;
F = M.Faces;

% Convert faces to double (required by all target types)
F = double(F);

% Dispatch based on target type
switch targetType
    case "surfaceMesh"
        % Create surfaceMesh object
        obj = surfaceMesh(V, F);
        
    case "triangulation"
        % Create triangulation object
        obj = triangulation(F, V);
        
    case "patch"
        % Create patch object in invisible figure
        fig = figure('Visible', 'off');
        obj = patch('Faces', F, 'Vertices', V);
        
        % Store figure handle in patch UserData for cleanup
        obj.UserData.Figure = fig;
        
    otherwise
        error('bct:manifold:UnsupportedTargetType', ...
            'Unsupported target type: %s', targetType);
end

end
