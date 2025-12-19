classdef Eigenpairs
    %EIGENPAIRS  Immutable spectral decomposition object
    %
    % Represents a set of eigenpairs (λ_k, u_k) of a self-adjoint operator
    % under a specific inner product defined by a mass matrix.
    %
    % Design principles (from EigenpairsContract):
    %   - Eigenpairs class owns meaning and invariants
    %   - bct.eigenpairs package owns algorithms and workflows
    %   - Immutable: no mutation, no solver calls
    %   - Identity-preserving operations only
    %
    % Construction:
    %   % Via factory functions (recommended)
    %   E = bct.eigenpairs.fromFEM(fem, k);
    %   
    %   % Direct construction (if eigenpairs already computed)
    %   E = bct.Eigenpairs(values, vectors, M, ...
    %           'operator', "Laplace-Beltrami", ...
    %           'basis', "P1-FEM", ...
    %           'manifoldID', id);
    %
    % Usage:
    %   % Projection / reconstruction
    %   coeffs = E.project(signal);
    %   signal = E.reconstruct(coeffs);
    %   
    %   % Subselection
    %   E_lowfreq = E.truncate(50);
    %   E_band = E.bandlimit([0.1, 1.0]);
    %   
    %   % Introspection
    %   k = E.numModes();
    %   energy = E.energy(coeffs);
    %
    % See also: bct.eigenpairs.fromFEM, bct.eigenpairs.validate

    properties (SetAccess = private)
        Values          % [k×1] eigenvalues
        Vectors         % [N×k] eigenvectors
        MassMatrix      % [N×N] mass matrix
        Operator        % string (e.g. "Laplace-Beltrami")
        Basis           % string (e.g. "P1-FEM")
        ManifoldID      % identifier / hash for safety
        Ordering        % string ("ascending")
    end

    methods
        function obj = Eigenpairs(values, vectors, M, meta)
            %EIGENPAIRS Constructor for Eigenpairs object
            %
            % Syntax:
            %   E = bct.Eigenpairs(values, vectors, M, ...
            %           'operator', op, 'basis', basis, 'manifoldID', id)
            %
            % Inputs:
            %   values  - [k×1] eigenvalues
            %   vectors - [N×k] eigenvectors (M-orthonormal)
            %   M       - [N×N] mass matrix
            %
            % Optional Parameters:
            %   operator   - String describing operator (e.g., "Laplace-Beltrami")
            %   basis      - String describing basis (e.g., "P1-FEM")
            %   manifoldID - String identifier for safety checks
            
            arguments
                values  (:,1) double
                vectors (:,:) double
                M       (:,:) double
                meta.operator   string
                meta.basis      string
                meta.manifoldID string
            end

            % Validate dimensions
            assert(size(vectors,2) == numel(values), ...
                'Eigenpairs:Mismatch', 'Values/vectors mismatch.');

            % Validate M-orthonormality
            I = vectors' * M * vectors;
            assert(norm(I - eye(size(I)), 'fro') < 1e-8, ...
                'Eigenpairs:NotOrthonormal', ...
                'Eigenvectors not orthonormal under mass matrix.');

            obj.Values     = values;
            obj.Vectors    = vectors;
            obj.MassMatrix = M;
            obj.Operator   = meta.operator;
            obj.Basis      = meta.basis;
            obj.ManifoldID = meta.manifoldID;
            obj.Ordering   = "ascending";
        end

        % -------------------------------------------------------------
        function coeffs = project(obj, signal)
            %PROJECT Project signal onto eigenbasis
            %
            % Syntax:
            %   coeffs = E.project(signal)
            %
            % Computes: coeffs = U' * M * signal
            
            coeffs = obj.Vectors' * obj.MassMatrix * signal;
        end

        function signal = reconstruct(obj, coeffs)
            %RECONSTRUCT Reconstruct signal from coefficients
            %
            % Syntax:
            %   signal = E.reconstruct(coeffs)
            %
            % Computes: signal = U * coeffs
            
            signal = obj.Vectors * coeffs;
        end
    end
    
    methods
        % -------------------------------------------------------------
        % Introspection / metadata methods
        % -------------------------------------------------------------
        
        function k = numModes(obj)
            %NUMMODES Get number of eigenmodes
            k = length(obj.Values);
        end
        
        function N = domainSize(obj)
            %DOMAINSIZE Get size of spatial domain
            N = size(obj.Vectors, 1);
        end
        
        function E = energy(obj, coeffs)
            %ENERGY Compute spectral energy
            %
            % Syntax:
            %   E = E.energy(coeffs)
            %
            % Computes: E = sum(λ_k * |c_k|^2)
            
            E = sum(obj.Values .* abs(coeffs).^2);
        end
        
        function E_sub = subselect(obj, indices)
            %SUBSELECT Create new Eigenpairs with subset of modes
            %
            % Syntax:
            %   E_sub = E.subselect(indices)
            %
            % Example:
            %   E_lowfreq = E.subselect(1:50);
            
            E_sub = bct.Eigenpairs(...
                obj.Values(indices), ...
                obj.Vectors(:, indices), ...
                obj.MassMatrix, ...
                'operator', obj.Operator, ...
                'basis', obj.Basis, ...
                'manifoldID', obj.ManifoldID);
        end
        
        function E_trunc = truncate(obj, k)
            %TRUNCATE Keep only first k modes
            %
            % Syntax:
            %   E_trunc = E.truncate(k)
            
            E_trunc = obj.subselect(1:min(k, obj.numModes()));
        end
        
        function E_band = bandlimit(obj, lambda_range)
            %BANDLIMIT Keep only modes within eigenvalue range
            %
            % Syntax:
            %   E_band = E.bandlimit([lambda_min, lambda_max])
            
            mask = obj.Values >= lambda_range(1) & obj.Values <= lambda_range(2);
            indices = find(mask);
            E_band = obj.subselect(indices);
        end
    end
end
