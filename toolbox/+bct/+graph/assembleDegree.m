function D = assembleDegree(A)
%ASSEMBLEDEGREE Build degree matrix from adjacency
%
% Syntax:
%   D = bct.graph.assembleDegree(A)
%
% Inputs:
%   A - [N×N] sparse adjacency matrix
%
% Returns:
%   D - [N×N] sparse diagonal degree matrix
%
% Notes:
%   - D(i,i) = degree of vertex i = sum(A(i,:))
%   - Result is diagonal matrix
%
% See also: bct.graph.assembleAdjacency

arguments
    A (:,:) {mustBeSparse}
end

d = sum(A, 2);
N = size(A, 1);
D = spdiags(d, 0, N, N);

end
