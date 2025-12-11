function snap = brainstormRawToSnapshot(raw)
%BRAINSTORMRAWTOSNAPSHOT Convert Brainstorm raw data to snapshot
%
%   snap = brainstormRawToSnapshot(raw) converts raw Brainstorm data
%   to a standardized snapshot structure.
%
%   Brainstorm meshes are already triangulated and 1-indexed.
%
%   Inputs:
%     raw.V      - Vertices (Nx3 double)
%     raw.F      - Faces (Mx3, already 1-indexed)
%     raw.meta   - Metadata (includes Comment, Atlas, etc.)
%
%   Returns:
%     snap.V     - Vertices (double)
%     snap.F     - Faces (int32)
%     snap.meta  - Metadata

    % Brainstorm faces are already 1-indexed and triangulated
    % Just ensure correct data types
    snap = struct(...
        'V', double(raw.V), ...
        'F', int32(raw.F), ...
        'meta', raw.meta ...
    );
end
