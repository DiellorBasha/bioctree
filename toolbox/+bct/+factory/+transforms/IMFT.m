classdef IMFT < bct.factory.transforms.TransformBase
    %IMFT  Inverse Mesh Fourier Transform
    %
    %   Inverse transform maps Lambda -> Space:
    %       x = U * c
    %
    %   The forward transform is:
    %       c = U' * (M * x)
    %
    %   Both U and M are stored in the respective domain objects.

    methods
        function obj = IMFT(lambdaDomain)
            % Base class constructor
            obj@bct.factory.transforms.TransformBase();

            % The dual of lambdaDomain is the Space domain
            spaceDomain = lambdaDomain.dual;

            if isempty(spaceDomain)
                error("IMFT: Lambda domain does not have a Space dual assigned.");
            end

            % Eigenvectors and mass matrix
            U = lambdaDomain.eigenvectors;   % [N x K]
            M = spaceDomain.M;               % [N x N]

            % ---------- Define forward and inverse transforms ------------
            obj.forward = @(c) U * c;         % Lambda -> Space
            obj.inverse = @(x) U' * (M * x);  % Space -> Lambda

            % ---------- Metadata -----------------------------------------
            obj.metadata.type     = 'Inverse Mesh Fourier Transform (IMFT)';
            obj.metadata.numModes = size(U,2);
            obj.metadata.lambda   = lambdaDomain.eigenvalues;
        end
    end
end
