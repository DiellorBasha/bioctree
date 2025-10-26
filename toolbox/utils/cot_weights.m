function [W_cot, M] = cot_weights(V, F)
% Compute symmetric cotangent-weight adjacency W and lumped mass M (vertex areas).
    V = double(V); F = double(F);
    N = size(V,1);

    i1 = F(:,1); i2 = F(:,2); i3 = F(:,3);
    v1 = V(i1,:); v2 = V(i2,:); v3 = V(i3,:);

    % Twice triangle area
    tri2A = vecnorm(cross(v2 - v1, v3 - v1, 2), 2, 2);     % ||(v2-v1) x (v3-v1)||
    Atri  = 0.5 * tri2A;

    % Cotangents (guard denominator)
    denom = max(tri2A, eps);
    cotA = dot(v2 - v1, v3 - v1, 2) ./ denom;  % angle at v1 (opposite edge i2-i3)
    cotB = dot(v3 - v2, v1 - v2, 2) ./ denom;  % angle at v2 (opposite edge i3-i1)
    cotC = dot(v1 - v3, v2 - v3, 2) ./ denom;  % angle at v3 (opposite edge i1-i2)

    % Assemble symmetric off-diagonal weights: 0.5*cot(angle opposite edge)
    I = [i2; i3; i3; i1; i1; i2];
    J = [i3; i2; i1; i3; i2; i1];
    S = 0.5 * [cotA; cotA; cotB; cotB; cotC; cotC];

    W_cot = sparse(I, J, S, N, N);
    W_cot = 0.5*(W_cot + W_cot.');                 % symmetrize
    W_cot = W_cot - spdiags(diag(W_cot), 0, N, N); % zero diagonal (paranoia)

    % Lumped mass matrix (barycentric area per vertex)
    Mv = accumarray([i1; i2; i3], [Atri; Atri; Atri]/3, [N 1], @sum, 0);
    M  = spdiags(Mv, 0, N, N);
end