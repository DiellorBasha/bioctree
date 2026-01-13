function L = assembleLaplacian(A, D, laplacianType)
%ASSEMBLELAPLACIAN Build graph Laplacian matrix
%
% Syntax:
%   L = bct.manifold.query.assembleLaplacian(A, D)
%   L = bct.manifold.query.assembleLaplacian(A, D, laplacianType)
%
% Inputs:
%   A             - [N×N] sparse adjacency matrix
%   D             - [N×N] sparse degree matrix
%   laplacianType - "combinatorial" (default), "normalized", "randomwalk"
%
% Returns:
%   L - [N×N] sparse graph Laplacian matrix
%
% Laplacian types:
%   - "combinatorial": L = D - A
%   - "normalized":    L = I - D^(-1/2) * A * D^(-1/2)
%   - "randomwalk":    L = I - D^(-1) * A
%
% See also: bct.manifold.query.assembleDegree

arguments
    A (:,:) {mustBeSparse}
    D (:,:) {mustBeSparse}
    laplacianType (1,1) string {mustBeMember(laplacianType, ["combinatorial","normalized","randomwalk"])} = "combinatorial"
end

N = size(A, 1);

switch laplacianType
    case "combinatorial"
        % L = D - A
        L = D - A;
        
    case "normalized"
        % L = I - D^{-1/2} A D^{-1/2}
        d = diag(D);
        d(d == 0) = eps;  % avoid division by zero
        Dinv2 = spdiags(1./sqrt(d), 0, N, N);
        L = speye(N) - Dinv2 * A * Dinv2;
        
    case "randomwalk"
        % L = I - D^{-1} A
        d = diag(D);
        d(d == 0) = eps;  % avoid division by zero
        Dinv = spdiags(1./d, 0, N, N);
        L = speye(N) - Dinv * A;
end

end
