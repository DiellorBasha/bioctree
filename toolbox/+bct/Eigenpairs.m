classdef Eigenpairs < handle
    %EIGENPAIRS  Spectral decomposition object with lazy evaluation
    %
    % Represents a set of eigenpairs (λ_k, u_k) of a self-adjoint operator
    % under a specific inner product defined by a mass matrix.
    %
    % Design principles (from EigenpairsContract):
    %   - Eigenpairs class owns meaning and invariants
    %   - bct.eigenpairs package owns algorithms and workflows
    %   - Lazy evaluation: eigensolve only runs when Values/Vectors accessed
    %   - Identity-preserving operations only
    %
    % Construction:
    %   % Via factory functions (recommended - lazy)
    %   E = bct.eigenpairs.fromFEM(fem, k);
    %   
    %   % Direct construction with precomputed eigenpairs
    %   E = bct.Eigenpairs(values, vectors, M, ...
    %           'operator', "Laplace-Beltrami", ...
    %           'basis', "P1-FEM", ...
    %           'manifoldID', id);
    %
    % Usage:
    %   % Projection / reconstruction (triggers computation if needed)
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
        MassMatrix      % [N×N] mass matrix
        Operator        % string (e.g. "Laplace-Beltrami")
        Basis           % string (e.g. "P1-FEM")
        ManifoldID      % identifier / hash for safety
        Ordering        % string ("ascending")
    end
    
    properties (Dependent)
        Values          % [k×1] eigenvalues (computed on first access)
        Vectors         % [N×k] eigenvectors (computed on first access)
    end
    
    properties (Access = private)
        StiffnessMatrix % [N×N] operator matrix (for lazy computation)
        NumModes_       % Number of modes to compute
        EigsOpts_       % Options for eigs solver
        RemoveDC_       % Whether to remove DC component
        
        Values_         % Cached eigenvalues
        Vectors_        % Cached eigenvectors
        IsComputed_     % Flag tracking computation state
    end

    methods
        function obj = Eigenpairs(varargin)
            %EIGENPAIRS Constructor for Eigenpairs object
            %
            % WARNING: DEPRECATED - Use bct.Manifold.eigenmodes() instead
            %
            %   The bct.Eigenpairs class is deprecated and will be removed in a future release.
            %   Use bct.Manifold.eigenmodes() for direct eigenmode computation:
            %
            %   Old: E = bct.eigenpairs.fromFEM(fem, 100);
            %   New: E = M.eigenmodes(100);
            %
            %   The returned structure contains:
            %     E.values    - [k×1] eigenvalues
            %     E.vectors   - [N×k] eigenvectors
            %
            % Syntax (precomputed):
            %   E = bct.Eigenpairs(values, vectors, M, ...
            %           'operator', op, 'basis', basis, 'manifoldID', id)
            %
            % Syntax (lazy, for use by factory functions):
            %   E = bct.Eigenpairs('K', K, 'M', M, 'k', k, ...
            %           'operator', op, 'basis', basis, 'manifoldID', id, ...
            %           'RemoveDC', true, 'EigsOpts', opts)
            %
            % Precomputed mode:
            %   values  - [k×1] eigenvalues
            %   vectors - [N×k] eigenvectors (M-orthonormal)
            %   M       - [N×N] mass matrix
            %
            % Lazy mode:
            %   K       - [N×N] stiffness/operator matrix
            %   M       - [N×N] mass matrix
            %   k       - Number of modes to compute
            %
            % Optional Parameters:
            %   operator   - String describing operator (e.g., "Laplace-Beltrami")
            %   basis      - String describing basis (e.g., "P1-FEM")
            %   manifoldID - String identifier for safety checks
            %   RemoveDC   - Remove DC component (default: true)
            %   EigsOpts   - Options struct passed to eigs
            %
            % See also: bct.Manifold.eigenmodes
            
            % Deprecation warning
            warning('bct:Eigenpairs:Deprecated', ...
                sprintf(['bct.Eigenpairs class is deprecated and will be removed in a future release.\n' ...
                         'Use bct.Manifold.eigenmodes() instead:\n' ...
                         '  Old: E = bct.eigenpairs.fromFEM(fem, k);\n' ...
                         '  New: E = M.eigenmodes(k); % Returns struct with .values and .vectors']));
            
            % Parse inputs to determine mode
            if nargin >= 3 && isnumeric(varargin{1}) && isnumeric(varargin{2}) && ...
                    ~isempty(varargin{1}) && ~isempty(varargin{2})
                % Precomputed mode: (values, vectors, M, ...)
                [obj, remainingArgs] = parsePrecomputed(obj, varargin{:});
                
                % Parse metadata
                p = inputParser;
                p.KeepUnmatched = false;
                addParameter(p, 'operator', "unknown", @isstring);
                addParameter(p, 'basis', "unknown", @isstring);
                addParameter(p, 'manifoldID', "", @isstring);
                parse(p, remainingArgs{:});
                
                obj.Operator = p.Results.operator;
                obj.Basis = p.Results.basis;
                obj.ManifoldID = p.Results.manifoldID;
                obj.Ordering = "ascending";
                obj.IsComputed_ = true;
                
                % Validate M-orthonormality
                I = obj.Vectors_' * obj.MassMatrix * obj.Vectors_;
                assert(norm(I - eye(size(I)), 'fro') < 1e-8, ...
                    'Eigenpairs:NotOrthonormal', ...
                    'Eigenvectors not orthonormal under mass matrix.');
                
            else
                % Lazy mode: ('K', K, 'M', M, 'numModes', k, ...)
                p = inputParser;
                p.KeepUnmatched = false;
                addParameter(p, 'K', [], @(x) issparse(x) || ismatrix(x));
                addParameter(p, 'M', [], @(x) issparse(x) || ismatrix(x));
                addParameter(p, 'numModes', [], @(x) isscalar(x) && x > 0);
                addParameter(p, 'operator', "unknown", @isstring);
                addParameter(p, 'basis', "unknown", @isstring);
                addParameter(p, 'manifoldID', "", @isstring);
                addParameter(p, 'RemoveDC', true, @islogical);
                addParameter(p, 'EigsOpts', struct(), @isstruct);
                parse(p, varargin{:});
                
                assert(~isempty(p.Results.K), 'Eigenpairs:MissingK', 'Stiffness matrix K required.');
                assert(~isempty(p.Results.M), 'Eigenpairs:MissingM', 'Mass matrix M required.');
                assert(~isempty(p.Results.numModes), 'Eigenpairs:MissingNumModes', 'Number of modes numModes required.');
                
                obj.StiffnessMatrix = p.Results.K;
                obj.MassMatrix = p.Results.M;
                obj.NumModes_ = p.Results.numModes;
                obj.RemoveDC_ = p.Results.RemoveDC;
                obj.EigsOpts_ = p.Results.EigsOpts;
                
                obj.Operator = p.Results.operator;
                obj.Basis = p.Results.basis;
                obj.ManifoldID = p.Results.manifoldID;
                obj.Ordering = "ascending";
                obj.IsComputed_ = false;
                obj.Values_ = [];
                obj.Vectors_ = [];
            end
        end
        
        % Dependent property getters (trigger lazy computation)
        function val = get.Values(obj)
            obj.computeIfNeeded();
            val = obj.Values_;
        end
        
        function vec = get.Vectors(obj)
            obj.computeIfNeeded();
            vec = obj.Vectors_;
        end

        % -------------------------------------------------------------
        function coeffs = project(obj, signal)
            %PROJECT Project signal onto eigenbasis
            %
            % Syntax:
            %   coeffs = E.project(signal)
            %
            % Computes: coeffs = U' * M * signal
            
            obj.computeIfNeeded();
            coeffs = obj.Vectors_' * obj.MassMatrix * signal;
        end

        function signal = reconstruct(obj, coeffs)
            %RECONSTRUCT Reconstruct signal from coefficients
            %
            % Syntax:
            %   signal = E.reconstruct(coeffs)
            %
            % Computes: signal = U * coeffs
            
            obj.computeIfNeeded();
            signal = obj.Vectors_ * coeffs;
        end
    end
    
    methods (Access = private)
        function [obj, remainingArgs] = parsePrecomputed(obj, values, vectors, M, varargin)
            %PARSEPRECOMPUTED Parse precomputed values/vectors constructor args
            
            % Validate dimensions
            assert(size(vectors,2) == numel(values), ...
                'Eigenpairs:Mismatch', 'Values/vectors mismatch.');
            
            obj.Values_ = values(:);
            obj.Vectors_ = vectors;
            obj.MassMatrix = M;
            remainingArgs = varargin;
        end
        
        function computeIfNeeded(obj)
            %COMPUTEIFNEEDED Lazily compute eigendecomposition on first access
            
            if obj.IsComputed_
                return;
            end
            
            % Solve generalized eigenproblem
            [U, lambda] = bct.eigenpairs.solveGeneralized(...
                obj.StiffnessMatrix, obj.MassMatrix, obj.NumModes_, ...
                'EigsOpts', obj.EigsOpts_);
            
            % Remove DC mode if requested
            if obj.RemoveDC_
                [U, lambda] = bct.eigenpairs.removeDC(U, lambda);
            end
            
            % Normalize eigenvectors
            U = bct.eigenpairs.normalize(U, obj.MassMatrix);
            
            % Cache results
            obj.Values_ = lambda;
            obj.Vectors_ = U;
            obj.IsComputed_ = true;
            
            % Report
            fprintf('bct.Eigenpairs: Lazy computation triggered\n');
            fprintf('  Requested modes: %d\n', obj.NumModes_);
            fprintf('  Retained modes:  %d\n', size(U, 2));
            fprintf('  Eigenvalue range: [%.6f, %.6f]\n', min(lambda), max(lambda));
        end
    end
    
    methods
        % -------------------------------------------------------------
        % Introspection / metadata methods
        % -------------------------------------------------------------
        
        function k = numModes(obj)
            %NUMMODES Get number of eigenmodes
            if obj.IsComputed_
                k = length(obj.Values_);
            else
                k = obj.NumModes_;  % Return requested, not computed
            end
        end
        
        function N = domainSize(obj)
            %DOMAINSIZE Get size of spatial domain
            N = size(obj.MassMatrix, 1);
        end
        
        function E = energy(obj, coeffs)
            %ENERGY Compute spectral energy
            %
            % Syntax:
            %   E = E.energy(coeffs)
            %
            % Computes: E = sum(λ_k * |c_k|^2)
            
            obj.computeIfNeeded();
            E = sum(obj.Values_ .* abs(coeffs).^2);
        end
        
        function E_sub = subselect(obj, indices)
            %SUBSELECT Create new Eigenpairs with subset of modes
            %
            % Syntax:
            %   E_sub = E.subselect(indices)
            %
            % Example:
            %   E_lowfreq = E.subselect(1:50);
            
            obj.computeIfNeeded();
            E_sub = bct.Eigenpairs(...
                obj.Values_(indices), ...
                obj.Vectors_(:, indices), ...
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
            
            obj.computeIfNeeded();
            E_trunc = obj.subselect(1:min(k, length(obj.Values_)));
        end
        
        function E_band = bandlimit(obj, lambda_range)
            %BANDLIMIT Keep only modes within eigenvalue range
            %
            % Syntax:
            %   E_band = E.bandlimit([lambda_min, lambda_max])
            
            obj.computeIfNeeded();
            mask = obj.Values_ >= lambda_range(1) & obj.Values_ <= lambda_range(2);
            indices = find(mask);
            E_band = obj.subselect(indices);
        end
    end
end
