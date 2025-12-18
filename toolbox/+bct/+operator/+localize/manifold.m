function out = manifold(M, kernelFn, vertices)
%BCT.OPERATOR.LOCALIZE.MANIFOLD
%   Localize a spectral kernel on a manifold at given vertex/vertices
%
%   Inputs:
%     M         - bct.Manifold
%     kernelFn  - function_handle (spectral kernel function)
%     vertices  - vertex indices for localization
%
%   Output:
%     out - bct.Signal on Manifold with localized kernel responses

    arguments
        M (1,1) bct.Manifold
        kernelFn (1,1) function_handle
        vertices (:,1) double {mustBeInteger}
    end

    % Delta signals
    N = M.N;
    f = zeros(N, numel(vertices));
    for k = 1:numel(vertices)
        f(vertices(k), k) = 1;
    end

    % Spectral filtering
    L = M.dual;          % Lambda
    U = L.U;
    lambda = L.lambda;

    coeff = U' * f;
    gvals = kernelFn(lambda);
    coeff = coeff .* gvals;
    data = U * coeff;

    % Create metadata
    meta = struct();
    meta.Operator = 'manifold_localize';
    meta.SeedVertices = vertices;

    out = bct.Signal(data, M, [], meta);
end
