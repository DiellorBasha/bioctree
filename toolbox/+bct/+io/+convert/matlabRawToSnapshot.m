function snap = matlabRawToSnapshot(raw)
%MATLABRAWTOSP Convert raw MATLAB mesh data to snapshot format
%
%   snap = matlabRawToSnapshot(raw) converts raw mesh structure to snapshot
%
%   Input:
%     raw - Structure from bct.io.in.readMat with fields:
%       .V - [N×3] vertices
%       .F - [M×3] faces
%
%   Output:
%     snap - Snapshot structure with fields:
%       .V - [N×3] vertices
%       .F - [M×3] faces (validated)
%
%   Example:
%     raw = bct.io.in.readMat('data/mesh.mat');
%     snap = bct.io.convert.matlabRawToSnapshot(raw);
%
%   See also: bct.io.in.readMat, bct.io.construct.mesh

    % Validate input
    if ~isstruct(raw) || ~isfield(raw, 'V') || ~isfield(raw, 'F')
        error('bct:io:convert:matlabRawToSnapshot:InvalidInput', ...
            'Input must be struct with V and F fields');
    end
    
    % Create snapshot
    snap = struct();
    snap.V = raw.V;
    snap.F = raw.F;
    
    % Ensure F is 1-based (MATLAB convention)
    if min(snap.F(:)) == 0
        warning('bct:io:convert:matlabRawToSnapshot:ZeroBased', ...
            'Face indices appear 0-based, converting to 1-based');
        snap.F = snap.F + 1;
    end
    
    % Validate face indices
    if max(snap.F(:)) > size(snap.V, 1)
        error('bct:io:convert:matlabRawToSnapshot:InvalidFaces', ...
            'Face indices exceed number of vertices');
    end
    
end
