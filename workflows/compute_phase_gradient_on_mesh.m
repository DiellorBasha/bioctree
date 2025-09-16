function grad_phi = compute_phase_gradient_on_mesh(V, F, phi_t)
% V: [nVertices x 3], vertex coordinates
% F: [nFaces x 3], triangle face indices
% phi_t: [nVertices x 1], phase values at a single time point
% Output grad_phi: [nVertices x 3], spatial phase gradient per vertex

nV = size(V, 1);
nF = size(F, 1);
grad_phi = zeros(nV, 3);
count = zeros(nV, 1);  % to average contributions

for f = 1:nF
    idx = F(f,:);               % indices of the triangle's 3 vertices
    coords = V(idx, :);         % 3 × 3 array of vertex coordinates
    values = phi_t(idx);        % 3 × 1 array of phase values at these vertices

    % Compute edge vectors
    e1 = coords(2,:) - coords(1,:);
    e2 = coords(3,:) - coords(1,:);
    E = [e1(:), e2(:)];         % 3×2 matrix for triangle basis

    % Phase differences
    dphi = [values(2) - values(1); values(3) - values(1)];  % 2 × 1

    grad3D = E * ((E' * E) \ dphi);  % Also gives 3 × 1


    % Accumulate to each vertex of the triangle
    for j = 1:3
        grad_phi(idx(j), :) = grad_phi(idx(j), :) + grad3D';
        count(idx(j)) = count(idx(j)) + 1;
    end
end

% Average the contributions from all adjacent faces
grad_phi = grad_phi ./ count;

end
