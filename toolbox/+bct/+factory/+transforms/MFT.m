classdef MFT < bct.factory.transforms.TransformBase
    %MFT  Mesh Fourier Transform (Manifold Fourier Transform)
    %
    %   Uses FEM Laplace–Beltrami eigenvectors and mass matrix.
    %
    %   Forward transform:   c = U' * (M * x)
    %   Inverse transform:   x = U * c
    %
    %   Eigenvectors U and eigenvalues λ are stored in the Lambda domain.
    %   Mass matrix M is stored in the Space domain.

    methods
        function obj = MFT(spaceDomain)
            % Call base class constructor
            obj@bct.factory.transforms.TransformBase();

            % The dual of spaceDomain is the Lambda domain
            lambdaDomain = spaceDomain.dual;

            if isempty(lambdaDomain)
                error("MFT: Space domain does not have a Lambda dual assigned.");
            end

            % Eigenvectors (basis functions)
            U = lambdaDomain.eigenvectors;     % [N x K]

            % Mass matrix (FEM geometry)
            M = spaceDomain.M;                 % [N x N]

            % ----------- Define forward and inverse transforms -----------
            obj.forward = @(x) U' * (M * x);   % Space -> Lambda
            obj.inverse = @(c) U * c;          % Lambda -> Space

            % ----------- Metadata for user / debugging -------------------
            obj.metadata.type      = 'Mesh Fourier Transform (MFT)';
            obj.metadata.numModes  = size(U,2);
            obj.metadata.lambda    = lambdaDomain.eigenvalues;
            obj.metadata.massDiag  = diag(M);  % optional summary of M
        end
    end
end
