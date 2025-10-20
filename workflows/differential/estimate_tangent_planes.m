function [tangentBasis] = estimate_tangent_planes(V, k)
    % Returns a 3D orthonormal basis (2x3) per sensor: each row is a tangent vector
    N = size(V,1);
    tangentBasis = zeros(N, 3, 2);  % N x 3 x 2

    Mdl = KDTreeSearcher(V);

    for i = 1:N
        [idx, ~] = knnsearch(Mdl, V(i,:), 'K', k+1);
        idx = idx(2:end);  % exclude self
        neighbors = V(idx, :);

        % PCA to get normal and tangent directions
        [coeff, ~, ~] = pca(neighbors);
        tangentBasis(i,:,1) = coeff(:,1);  % First tangent vector
        tangentBasis(i,:,2) = coeff(:,2);  % Second tangent vector
        % coeff(:,3) is normal, orthogonal to the tangent plane
    end
end
