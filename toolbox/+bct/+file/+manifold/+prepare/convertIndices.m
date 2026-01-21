function [faces0, edges0] = convertIndices(faces, edges)
%CONVERTINDICES  Convert MATLAB 1-based indices to 0-based for export
%
%   [faces0, edges0] = bct.file.manifold.prepare.convertIndices(faces, edges)
%
% Purpose
%   Converts face and edge connectivity arrays from MATLAB's 1-based
%   indexing convention to 0-based indexing for downstream consumption
%   (JavaScript, Python, HDF5/Zarr interchange).
%
% Inputs
%   faces - [F×3] uint32, face connectivity (1-based)
%   edges - [E×2] uint32, edge connectivity (1-based)
%
% Outputs
%   faces0 - [F×3] uint32, face connectivity (0-based)
%   edges0 - [E×2] uint32, edge connectivity (0-based)
%
% Export Policy
%   - Internal MATLAB: 1-based (min index = 1)
%   - Export files: 0-based (min index = 0)
%   - Conversion: subtract 1 from all indices
%
% Examples
%   % Convert for export
%   [F0, E0] = bct.file.manifold.prepare.convertIndices(M.Faces, M.Edges);
%   assert(min(F0(:)) == 0, 'Faces should be 0-based');
%
% See also: bct.file.manifold.write.core, bct.file.manifold.write.zarr

arguments
    faces uint32
    edges uint32
end

% Convert to 0-based indexing
faces0 = faces - 1;
edges0 = edges - 1;

end
