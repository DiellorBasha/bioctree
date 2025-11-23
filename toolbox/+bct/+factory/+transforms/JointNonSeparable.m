classdef JointNonSeparable < bct.factory.transforms.TransformBase
    %JOINTNONSEPARABLE  Non-separable joint transform for Joint domains
    %
    %   This class applies a full 2D joint basis Φ that is NOT expressible
    %   as a Kronecker product (U ⊗ V) of separable bases. This enables
    %   modeling of coupled spatiotemporal phenomena that cannot be captured
    %   by separable transforms.
    %
    %   Forward:  X_hat = reshape(Φ' * X(:), sizeOut)
    %   Inverse:  X     = reshape(Φ * X_hat(:), sizeIn)
    %
    %   The full joint basis Φ can be:
    %     - Wave packets (spatially and temporally localized)
    %     - Chirped atoms (frequency-modulated wavelets)
    %     - Gabor atoms (time-frequency localized)
    %     - Velocity-tuned filters (traveling wave detectors)
    %     - Scattering dictionaries (multi-scale feature extractors)
    %     - Learned joint CNN kernels (data-driven representations)
    %     - Motion-sensitive filters (directional spatiotemporal filters)
    %
    %   Unlike separable transforms where transform(X) = U'*X*V, the
    %   non-separable transform vectorizes X and applies a full matrix Φ.
    %
    % Properties:
    %   Phi      - Full joint basis matrix [N_modes*T_modes × N*T]
    %   sizeIn   - Input signal dimensions [N, T]
    %   sizeOut  - Output coefficient dimensions [N_modes, T_modes]
    %   Domain1  - First domain (e.g., Manifold or Lambda)
    %   Domain2  - Second domain (e.g., Time or Omega)
    %
    % Example:
    %   % Create wave packet dictionary for traveling wave analysis
    %   Phi = createWavePacketBasis(B.Manifold, B.Time);
    %   transform = bct.factory.transforms.JointNonSeparable(...
    %       B.Manifold, B.Time, Phi, [N, T], [K, F]);
    %
    %   % Apply forward transform
    %   coeffs = transform.forward(X);  % Extract wave packet coefficients
    %
    %   % Reconstruct signal
    %   X_recon = transform.inverse(coeffs);
    %
    % See also: bct.factory.transforms.JointSeparable, bct.factory.transforms.TransformBase

    properties
        Phi        % Full joint basis: [N_modes*T_modes × N*T]
        sizeIn     % Input dimensions [N, T]
        sizeOut    % Output dimensions [N_modes, T_modes]
        Domain1    % First domain (spatial/spectral)
        Domain2    % Second domain (temporal/frequency)
    end

    methods
        function obj = JointNonSeparable(domain1, domain2, Phi, sizeIn, sizeOut)
            %JOINTNONSEPARABLE Construct non-separable joint transform
            %
            %   obj = JointNonSeparable(domain1, domain2, Phi, sizeIn, sizeOut)
            %
            % Inputs:
            %   domain1 - First domain object (e.g., Manifold, Lambda)
            %   domain2 - Second domain object (e.g., Time, Omega)
            %   Phi     - Full joint basis matrix [prod(sizeOut) × prod(sizeIn)]
            %   sizeIn  - Input signal dimensions [N, T]
            %   sizeOut - Output coefficient dimensions [N_modes, T_modes]
            %
            % The basis matrix Φ should satisfy:
            %   - size(Phi, 1) = prod(sizeOut)  (number of basis atoms)
            %   - size(Phi, 2) = prod(sizeIn)   (signal dimension)
            %   - For orthonormal basis: Φ'*Φ = I
            %   - For tight frame: Φ*Φ' = c*I for some constant c
            
            % Call base class constructor
            obj@bct.factory.transforms.TransformBase();

            % Validate inputs
            if nargin < 5
                error('JointNonSeparable:InvalidInput', ...
                    'Requires 5 arguments: domain1, domain2, Phi, sizeIn, sizeOut');
            end
            
            % Validate dimensions
            expectedCols = prod(sizeIn);
            expectedRows = prod(sizeOut);
            
            if size(Phi, 2) ~= expectedCols
                error('JointNonSeparable:DimensionMismatch', ...
                    'Phi columns (%d) must match prod(sizeIn) = %d', ...
                    size(Phi, 2), expectedCols);
            end
            
            if size(Phi, 1) ~= expectedRows
                error('JointNonSeparable:DimensionMismatch', ...
                    'Phi rows (%d) must match prod(sizeOut) = %d', ...
                    size(Phi, 1), expectedRows);
            end

            % Store properties
            obj.Domain1 = domain1;
            obj.Domain2 = domain2;
            obj.Phi     = Phi;
            obj.sizeIn  = sizeIn;
            obj.sizeOut = sizeOut;

            % Define FORWARD transform: X → X_hat
            % Vectorize input, apply basis transpose, reshape to output size
            obj.forward = @(X) reshape( ...
                obj.Phi' * X(:), ...
                obj.sizeOut);

            % Define INVERSE transform: X_hat → X
            % Vectorize coefficients, apply basis, reshape to input size
            obj.inverse = @(Xhat) reshape( ...
                obj.Phi * Xhat(:), ...
                obj.sizeIn);

            % Store metadata
            obj.metadata.type        = 'Joint Non-Separable Transform';
            obj.metadata.sizeIn      = sizeIn;
            obj.metadata.sizeOut     = sizeOut;
            obj.metadata.numAtoms    = size(Phi, 1);
            obj.metadata.numSamples  = size(Phi, 2);
            obj.metadata.domain1     = class(domain1);
            obj.metadata.domain2     = class(domain2);
            obj.metadata.basisShape  = size(Phi);
            
            % Check if basis is orthonormal (for informational purposes)
            if size(Phi, 1) == size(Phi, 2)
                % Square matrix - check orthonormality
                identity_error = norm(Phi' * Phi - eye(size(Phi, 1)), 'fro');
                if identity_error < 1e-10
                    obj.metadata.basisType = 'Orthonormal';
                else
                    obj.metadata.basisType = 'Overcomplete or General';
                end
            else
                obj.metadata.basisType = 'Overcomplete or General';
            end
        end
    end
end
