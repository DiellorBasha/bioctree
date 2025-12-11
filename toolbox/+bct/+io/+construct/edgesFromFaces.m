function E = edgesFromFaces(F)
%EDGESFROMFACES Extract unique edges from triangle faces
%
%   E = edgesFromFaces(F) extracts all unique edges from faces
%
%   Inputs:
%     F - Mx3 triangle faces
%
%   Returns:
%     E - Kx2 unique edges (int32)

    e12 = sort(F(:, [1 2]), 2);
    e23 = sort(F(:, [2 3]), 2);
    e31 = sort(F(:, [3 1]), 2);
    
    E = int32(unique([e12; e23; e31], 'rows'));
end
