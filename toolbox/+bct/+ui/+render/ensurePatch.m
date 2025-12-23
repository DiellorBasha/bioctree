function h = ensurePatch(ax, vertices, faces, options)
%BCT.UI.RENDER.ENSUREPATCH  Create or update patch graphics primitive
%
%   h = bct.ui.render.ensurePatch(ax, vertices, faces)
%   h = bct.ui.render.ensurePatch(ax, vertices, faces, Name, Value, ...)
%
% Purpose
%   Low-level rendering primitive for patch creation/update.
%   Handles graphics object lifecycle and property configuration.
%
% Inputs
%   ax       - UIAxes or axes handle
%   vertices - [N×3] double: vertex positions
%   faces    - [M×3] int32: face connectivity
%
% Name-Value Arguments
%   Handle           - existing patch handle to update (default: [])
%   FaceColor        - color spec (default: [0.6 0.6 0.6])
%   EdgeColor        - color spec (default: 'none')
%   FaceLighting     - 'gouraud' | 'flat' | 'none' (default: 'gouraud')
%   AmbientStrength  - scalar [0,1] (default: 0.15)
%   DiffuseStrength  - scalar [0,1] (default: 0.7)
%   SpecularStrength - scalar [0,1] (default: 0.05)
%   SpecularExponent - scalar > 0 (default: 35)
%   FaceAlpha        - scalar [0,1] (default: 1)
%
% Output
%   h - patch handle
%
% Contract
%   - If Handle is valid, updates existing patch
%   - If Handle is invalid/empty, creates new patch
%   - Always returns valid handle or errors
%
% See also: patch, bct.ui.render.updatePatchVertexRGB

    arguments
        ax
        vertices (:,3) double
        faces (:,3)
        options.Handle = []
        options.FaceColor = [0.6 0.6 0.6]
        options.EdgeColor = 'none'
        options.FaceLighting (1,1) string = "gouraud"
        options.AmbientStrength (1,1) double = 0.15
        options.DiffuseStrength (1,1) double = 0.7
        options.SpecularStrength (1,1) double = 0.05
        options.SpecularExponent (1,1) double = 35
        options.FaceAlpha (1,1) double = 1
    end
    
    % Check if existing handle is valid
    updateExisting = ~isempty(options.Handle) && isvalid(options.Handle) && isgraphics(options.Handle, 'patch');
    
    if updateExisting
        % Update existing patch
        h = options.Handle;
        set(h, 'Vertices', vertices, 'Faces', double(faces));
    else
        % Create new patch
        h = patch(ax, ...
            'Vertices', vertices, ...
            'Faces', double(faces), ...
            'EdgeColor', options.EdgeColor, ...
            'FaceColor', options.FaceColor);
    end
    
    % Configure material properties
    set(h, ...
        'FaceLighting', char(options.FaceLighting), ...
        'AmbientStrength', options.AmbientStrength, ...
        'DiffuseStrength', options.DiffuseStrength, ...
        'SpecularStrength', options.SpecularStrength, ...
        'SpecularExponent', options.SpecularExponent, ...
        'FaceAlpha', options.FaceAlpha);
    
    % Set edge color if not already set during creation
    if updateExisting
        set(h, 'EdgeColor', options.EdgeColor);
    end
end
