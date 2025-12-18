function out = imft(in)
%BCT.OPERATOR.TRANSFORM.IMFT
%   Inverse Manifold Fourier Transform (FEM-based)
%
%   x_rec = Phi * x_hat
%
%   where Phi are the eigenmodes. The mass matrix is not needed in the
%   inverse transform since the forward transform already incorporated it.
%
%   Input:
%     in  - bct.Signal on Lambda (mode-based)
%   Output:
%     out - bct.Signal on Manifold (vertex-based)

    arguments
        in (1,1) bct.Signal
    end

    if ~isa(in.Domain, 'bct.Lambda')
        error("bct:operator:imft:InvalidDomain", ...
            "Input Signal must live on Lambda domain.");
    end

    L = in.Domain;          % bct.Lambda
    M_manifold = L.dual;    % bct.Manifold
    
    % Validate dual domain exists
    if isempty(M_manifold)
        error("bct:operator:imft:NoDual", ...
            "Lambda domain has no dual Manifold domain set.");
    end
    
    if ~isa(M_manifold, 'bct.Manifold')
        error("bct:operator:imft:InvalidDual", ...
            "Lambda dual is not a bct.Manifold (got %s)", class(M_manifold));
    end

    % Get eigenmodes
    Phi = L.U;              % [N x K] eigenmodes
    
    % Compute Inverse Manifold Fourier Transform
    % x_rec = Phi * x_hat
    data = Phi * in.Data;

    % Create metadata
    meta = struct();
    meta.Operator = 'imft';
    meta.ParentSignal = in.Id;

    out = bct.Signal(data, M_manifold, [], meta);
end
