function snap = freeSurferRawToSnapshot(raw)
%FREESURFERRAWTOSNAPSHOT Convert FreeSurfer raw data to snapshot
%
%   snap = freeSurferRawToSnapshot(raw) converts raw FreeSurfer data
%   to a standardized snapshot structure.
%
%   For quad meshes, automatically triangulates by default.
%
%   Inputs:
%     raw.V      - Vertices
%     raw.F      - Faces (possibly quads)
%     raw.meta   - Metadata
%
%   Returns:
%     snap.V     - Vertices (double)
%     snap.F     - Faces (int32, triangulated if needed)
%     snap.meta  - Metadata

    V = raw.V;
    F = raw.F;
    
    % Triangulate quads if present
    if size(F, 2) == 4
        F = bct.io.convert.triangulateQuads(F);
    end
    
    snap = struct(...
        'V', double(V), ...
        'F', int32(F), ...
        'meta', raw.meta ...
    );
end
