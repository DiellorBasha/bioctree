function out = manifold(in, k)
%BCT.OPERATOR.MODULATE.MANIFOLD
%   Point (eigenmode-index) modulation of a manifold signal
%
%   FEM analogue of gsp_modulate:
%       fm(x) = sqrt(N) * f(x) .* phi_k(x)
%
%   Inputs:
     in  - bct.Signal on Manifold (vertex-based)
%     k   - eigenmode index (1-based, MATLAB indexing)
%
%   Output:
%     out - bct.Signal on Manifold (vertex-based)

    arguments
        in (1,1) bct.Signal
        k (1,1) double {mustBeInteger, mustBePositive}
    end

    if ~isa(in.Domain, 'bct.Manifold')
        error("bct:operator:modulate:manifold:InvalidDomain", ...
            "Input Signal must live on a Manifold domain.");
    end

    % Retrieve manifold and eigenmodes
    M = in.Domain;       % bct.Manifold
    L = M.dual;          % bct.Lambda
    U = L.U;

    if k > size(U,2)
        error("bct:operator:modulate:manifold:IndexOutOfRange", ...
            "Eigenmode index k exceeds available modes.");
    end

    % Apply modulation
    N = M.N;
    phi_k = U(:,k);
    data = sqrt(N) .* in.Data .* phi_k;

    % Output Signal
    meta = struct();
    meta.Operator = 'manifold_modulate';
    meta.ModeIndex = k;
    meta.ParentSignal = in.Id;

    out = bct.Signal(data, M, [], meta);
end
