function obj = convert(source, target)
%CONVERT Universal converter between Manifold and MATLAB geometry objects
%
% Syntax:
%   obj = bct.manifold.convert(source, target)
%
% This function provides bidirectional conversion:
%   - Geometry object → Manifold (delegates to bct.manifold.in)
%   - Manifold → Geometry object (delegates to bct.manifold.out)
%   - Geometry object → Geometry object (via Manifold intermediary)
%
% Supported Types:
%   - bct.Manifold
%   - surfaceMesh
%   - triangulation
%   - Patch (graphics object)
%
% Inputs:
%   source - Source object (Manifold or geometry object)
%   target - Target type (string or bct.Manifold)
%            For geometry objects: "surfaceMesh", "triangulation", "patch", or "Manifold"
%
% Outputs:
%   obj - Converted object of target type
%
% Examples:
%   % Geometry → Manifold
%   smesh = surfaceMesh(V, F);
%   M = bct.manifold.convert(smesh, "Manifold");
%
%   % Manifold → Geometry
%   tri = bct.manifold.convert(M, "triangulation");
%
%   % Geometry → Geometry (automatic round-trip)
%   tri = triangulation(F, V);
%   smesh = bct.manifold.convert(tri, "surfaceMesh");
%
%   % From Manifold class
%   M = bct.Manifold(V, F);
%   p = bct.manifold.convert(M, "patch");
%
% See also: bct.manifold.in, bct.manifold.out, bct.Manifold

arguments
    source
    target {mustBeTextOrManifold}
end

% Determine conversion path
if isa(source, 'bct.Manifold')
    % Manifold → Geometry object
    if isstring(target) || ischar(target)
        target = string(target);
        if target == "Manifold"
            % Already a Manifold, return as-is
            obj = source;
        else
            % Convert Manifold to target geometry type
            obj = bct.manifold.out(source, target);
        end
    else
        error('bct:manifold:InvalidTarget', ...
            'Target must be a string when source is Manifold: "surfaceMesh", "triangulation", or "patch"');
    end
    
elseif isa(source, 'surfaceMesh') || isa(source, 'triangulation') || ...
       isa(source, 'matlab.graphics.primitive.Patch') || strcmp(class(source), 'patch')
    % Geometry object → ?
    if isstring(target) || ischar(target)
        target = string(target);
        if target == "Manifold"
            % Geometry → Manifold
            obj = bct.manifold.in(source);
        else
            % Geometry → Geometry (via Manifold)
            M = bct.manifold.in(source);
            obj = bct.manifold.out(M, target);
        end
    else
        error('bct:manifold:InvalidTarget', ...
            'Target must be a string: "Manifold", "surfaceMesh", "triangulation", or "patch"');
    end
    
else
    error('bct:manifold:UnsupportedSource', ...
        'Unsupported source type: %s. Expected bct.Manifold, surfaceMesh, triangulation, or Patch.', ...
        class(source));
end

end

% Validation function
function mustBeTextOrManifold(val)
    if ~(isstring(val) || ischar(val) || isa(val, 'bct.Manifold'))
        error('bct:manifold:InvalidTarget', ...
            'Target must be a string or bct.Manifold');
    end
end
