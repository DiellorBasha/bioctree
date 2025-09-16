function gradients = estimate_gradients(V, f, k)
    % Inputs:
    % V: Nx3 sensor coordinates
    % f: Nx1 scalar field at sensors (e.g., F_alpha(:, t))
    % k: number of neighbors to use

    N = size(V, 1);
    gradients = zeros(N, 3);

    % Build k-d tree for neighbor search
    Mdl = KDTreeSearcher(V);

    for i = 1:N
        % Get k-nearest neighbors (including self)
        [idx, D] = knnsearch(Mdl, V(i,:), 'K', k+1);  % +1 to include self
        idx = idx(2:end);  % remove self

        % Build matrix of position differences
        X = V(idx, :) - V(i, :);      % (k x 3)
        y = f(idx) - f(i);            % (k x 1)

        % Solve least squares: minimize ||X * grad - y||
        grad = X \ y;
        gradients(i, :) = grad';
    end
end
