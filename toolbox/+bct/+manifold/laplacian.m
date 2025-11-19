function [L, M, K] = laplacian(V, F, laplacianType)
%LAPLACIAN  Compute cotangent Laplacian (cotangent or cotangent-normalized)
%
%   [L, M, K] = laplacian(V, F, laplacianType)
%
% Inputs:
%   V   : Nx3 vertex coordinates
%   F   : Mx3 face indices
%   laplacianType : "cotangent" or "cotangent-normalized"
%
% Outputs:
%   L : The Laplacian matrix of chosen type:
%         - cotangent:   L = M^{-1} K
%         - cotangent-normalized:     L = M^{-1/2} K M^{-1/2}
%   M : N×N sparse diagonal mass matrix
%   K : N×N sparse cotangent stiffness matrix (positive semi-definite)
%
% Notes:
%   - Uses gptoolbox functions: cotmatrix, massmatrix
%   - For cotangent Laplacian, this returns the operator L = M^{-1}K
%     suitable for spectral analysis: L φ = λ φ.
%   - For cotangent-normalized Laplacian, eigenproblem is L φ = λ φ with orthonormal φ.

    arguments
        V double
        F double
        laplacianType (1,1) string {mustBeMember(laplacianType,["cotangent","cotangent-normalized"])}
    end

% ensures gptbox is available
    % --- Cotangent stiffness ---
    K = -cotmatrix(V, F); 
    K = (K + K.') / 2;       % enforce symmetry

    % --- Lumped mass matrix ---
    Mfull = massmatrix(V, F, 'barycentric');
    d = full(diag(Mfull));
    M = spdiags(d, 0, length(d), length(d));

    switch laplacianType

        case "cotangent"
            % cotangent Laplace–Beltrami:
            %     L = M^{-1} K
            Minv = spdiags(1 ./ d, 0, length(d), length(d));
            L = Minv * K;

        case "cotangent-normalized"
            % Symmetric cotangent-normalized Laplacian:
            %     L = M^{-1/2} K M^{-1/2}
            Sinv = spdiags(1 ./ sqrt(d), 0, length(d), length(d));
            L = Sinv * K * Sinv;
            L = (L + L.') / 2; % ensure symmetry

    end
end
