function updatePatchVertexRGB(h, cdata)
%BCT.UI.RENDER.UPDATEPATCHVERTEXRGB  Update patch with per-vertex RGB colors
%
%   bct.ui.render.updatePatchVertexRGB(h, cdata)
%
% Purpose
%   Low-level primitive for updating patch vertex colors.
%   Separates color application from color computation.
%
% Inputs
%   h     - patch handle
%   cdata - [N×3] double, RGB values in [0,1] for each vertex
%
% Contract
%   - Validates cdata dimensions match patch vertices
%   - Sets FaceColor='interp' and FaceVertexCData
%   - Errors if handle is invalid or size mismatch
%
% See also: bct.ui.data.scalarToVertexCData, bct.ui.render.ensurePatch

    arguments
        h (1,1) {mustBeA(h, 'matlab.graphics.primitive.Patch')}
        cdata (:,3) double
    end
    
    if ~isvalid(h)
        error('bct:ui:render:InvalidHandle', 'Patch handle is not valid');
    end
    
    % Validate size
    nVerts = size(h.Vertices, 1);
    if size(cdata, 1) ~= nVerts
        error('bct:ui:render:SizeMismatch', ...
            'cdata has %d rows but patch has %d vertices', ...
            size(cdata, 1), nVerts);
    end
    
    % Validate range
    if any(cdata(:) < 0 | cdata(:) > 1)
        warning('bct:ui:render:ColorOutOfRange', ...
            'cdata contains values outside [0,1]. Clamping.');
        cdata = max(0, min(1, cdata));
    end
    
    % Update patch
    set(h, ...
        'FaceVertexCData', cdata, ...
        'FaceColor', 'interp');
end
