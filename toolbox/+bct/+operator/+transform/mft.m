function out = mft(in)
%BCT.OPERATOR.TRANSFORM.MFT
%   Manifold Fourier Transform (FEM-based)
%
%   x_hat = Phi' * M * x
%
%   where M is the Mass Matrix (vertex areas) from the Finite Element
%   Method discretization, and Phi are the eigenmodes.
%
%   Input:
%     in  - bct.Signal on Manifold (vertex-based)
%   Output:
%     out - bct.Signal on Lambda (mode-based)

    arguments
        in (1,1) bct.Signal
    end

    if ~isa(in.Domain, 'bct.Manifold')
        error("bct:operator:mft:InvalidDomain", ...
            "Input Signal must live on a Manifold domain.");
    end

    M_manifold = in.Domain;     % bct.Manifold
    L = M_manifold.dual;        % bct.Lambda

    % Get eigenmodes and mass matrix
    Phi = L.U;                   % [N x K] eigenmodes
    M = M_manifold.MassMatrix;   % [N x N] diagonal mass matrix (vertex areas)
    
    % Compute FEM-based Manifold Fourier Transform
    % x_hat = Phi' * M * x
    coeff = Phi' * (M * in.Data);

    % Create metadata
    meta = struct();
    meta.Operator = 'mft';
    meta.ParentSignal = in.Id;

    out = bct.Signal(coeff, L, [], meta);
end
