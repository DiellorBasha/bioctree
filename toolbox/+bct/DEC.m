classdef DEC < handle
    %bct.DEC  Discrete Exterior Calculus (DEC) representation for a Manifold
    %
    % DESIGN CONTRACT (summary):
    %   - bct.DEC is a THIN semantic wrapper around the DECLab backend:
    %       DiscreteExteriorCalculus(Faces, Vertices)
    %   - bct.DEC performs NO DEC computations itself.
    %   - All DEC-related operators live in +bct/+dec/ as pure functions and
    %     must consume the backend through this wrapper (DEC.Backend).
    %   - bct.DEC may cache derived backend-access results if strictly needed,
    %     but must not introduce new discretizations or numerical routines.
    %
    % CONSTRUCTION:
    %   D = bct.DEC(M) where M is a bct.Manifold
    %
    % PRIMARY STATE:
    %   - Manifold: parent manifold (geometry/topology authority)
    %   - Backend : DECLab DiscreteExteriorCalculus object (math authority)
    %
    % SEE ALSO:
    %   bct.dec.* , DiscreteExteriorCalculus (DECLab)

    properties (SetAccess = private)
        Manifold   (1,1)              % Parent manifold (geometry authority)
        Backend                        % DECLab DiscreteExteriorCalculus (math authority)
        BackendInfo (1,1) struct = struct()  % Optional diagnostics metadata
    end
    
    properties (Dependent)
        Gradient     % [E×V] gradient operator (0-forms → 1-forms)
        Divergence   % [V×E] divergence operator (1-forms → 0-forms)
        Curl         % [F×E] curl operator (1-forms → 2-forms)
    end

    properties (Access = private)
        Cache    % Optional cache of backend-derived objects (containers.Map)
    end

    methods
        function obj = DEC(M)
            %DEC Construct DEC representation from a bct.Manifold
            %
            % Syntax:
            %   D = bct.DEC(M)
            %
            % Inputs:
            %   M - bct.Manifold instance (must provide Faces and Vertices)
            %
            % Notes:
            %   - This constructor instantiates the DECLab backend.
            %   - It must not perform any DEC computations beyond backend construction.

            arguments
                M (1,1)
            end

            obj.Manifold = M;
            obj.Cache = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % Validate minimal manifold requirements
            if ~isprop(M, "Faces") || isempty(M.Faces)
                error("bct:DEC:MissingFaces", ...
                    "Manifold must provide non-empty Faces to construct DEC.");
            end
            if ~isprop(M, "Vertices") || isempty(M.Vertices)
                error("bct:DEC:MissingVertices", ...
                    "Manifold must provide non-empty Vertices to construct DEC.");
            end

            % DECLab convention: DiscreteExteriorCalculus(Faces, Vertices)
            % Ensure types are compatible with backend expectations.
            F = double(M.Faces);
            V = double(M.Vertices);

            try
                obj.Backend = DiscreteExteriorCalculus(F, V);
            catch ME
                error("bct:DEC:BackendInitFailed", ...
                    "Failed to initialize DECLab DiscreteExteriorCalculus: %s", ME.message);
            end

            % Optional backend diagnostics metadata (non-authoritative)
            obj.BackendInfo = struct( ...
                "backend", "DECLab", ...
                "class", string(class(obj.Backend)), ...
                "numVertices", size(V,1), ...
                "numFaces", size(F,1) );
        end

        function B = backend(obj)
            %backend Return DECLab backend (read-only access by convention)
            B = obj.Backend;
        end

        function tf = isAvailable(obj)
            %isAvailable True if DEC backend exists and is valid
            tf = ~isempty(obj.Backend);
        end

        function clearCache(obj)
            %clearCache Clear internal cache (does not modify backend)
            remove(obj.Cache, keys(obj.Cache));
        end
        
        function E = eigenpairs(obj, formDegree, k, options)
            %EIGENPAIRS Compute eigenpairs for k-form Laplacian
            %
            % Syntax:
            %   E = D.eigenpairs(formDegree, k)
            %   E = D.eigenpairs(formDegree, k, 'Force', true)
            %
            % Inputs:
            %   formDegree - 0, 1, or 2 (form degree)
            %   k          - Number of eigenpairs to compute
            %
            % Optional Parameters:
            %   Force - Recompute even if cached (default: false)
            %
            % Outputs:
            %   E - bct.Eigenpairs object
            %
            % Note: Delegates to bct.dec.eigensolve
            %
            % See also: bct.dec.eigensolve, bct.Eigenpairs
            
            arguments
                obj (1,1) bct.DEC
                formDegree (1,1) {mustBeInteger, mustBeNonnegative}
                k (1,1) {mustBePositive, mustBeInteger}
                options.Force (1,1) logical = false
            end
            
            % Validate form degree
            if formDegree > 2
                error('bct:DEC:InvalidFormDegree', ...
                    'Form degree must be 0, 1, or 2 for 2D manifolds');
            end
            
            % Check cache
            key = sprintf("form%d_k=%d", formDegree, k);
            if ~options.Force && isKey(obj.Cache, key)
                E = obj.Cache(key);
                return;
            end
            
            % Delegate to bct.dec.eigensolve
            E = bct.dec.eigensolve(obj, formDegree, k);
            
            % Cache result
            obj.Cache(key) = E;
        end

        % ---- Optional: thin pass-through accessors (NO computations) ----
        % These accessors exist only to standardize access patterns and reduce
        % scattered direct backend property access across bct.dec.* functions.
        % If DECLab changes field names, you update these accessors (and/or
        % the bct.dec primitive functions) rather than user code.

        function op = d0(obj)
            %d0 Exterior derivative from 0-forms to 1-forms (pass-through)
            % Prefer using bct.dec.d0(DEC) in operator code for consistency.
            op = obj.getBackendField_("d0");
        end

        function op = d1(obj)
            %d1 Exterior derivative from 1-forms to 2-forms (pass-through)
            op = obj.getBackendField_("d1");
        end

        function op = star0(obj)
            %star0 Hodge star on 0-forms (pass-through to hd0)
            op = obj.getBackendField_("hd0");
        end

        function op = star1(obj)
            %star1 Hodge star on 1-forms (pass-through to hd1)
            op = obj.getBackendField_("hd1");
        end

        function op = star2(obj)
            %star2 Hodge star on 2-forms (pass-through to hd2)
            op = obj.getBackendField_("hd2");
        end
        
        % ---- Differential operators (cached) ----
        
        function op = get.Gradient(obj)
            %get.Gradient Get gradient operator (d0)
            %
            % Returns:
            %   op - [E×V] sparse matrix mapping 0-forms to 1-forms
            %
            % Note: Equivalent to d0, cached for convenience
            if ~isKey(obj.Cache, 'Gradient')
                obj.Cache('Gradient') = bct.dec.d0(obj);
            end
            op = obj.Cache('Gradient');
        end
        
        function op = get.Divergence(obj)
            %get.Divergence Get divergence operator (-d0' * star1)
            %
            % Returns:
            %   op - [V×E] sparse matrix mapping 1-forms to 0-forms
            %
            % Note: Adjoint of gradient under Hodge inner product
            if ~isKey(obj.Cache, 'Divergence')
                d0 = bct.dec.d0(obj);
                star1 = bct.dec.star1(obj);
                obj.Cache('Divergence') = -d0' * star1;
            end
            op = obj.Cache('Divergence');
        end
        
        function op = get.Curl(obj)
            %get.Curl Get curl operator (d1)
            %
            % Returns:
            %   op - [F×E] sparse matrix mapping 1-forms to 2-forms
            %
            % Note: Equivalent to d1, cached for convenience
            if ~isKey(obj.Cache, 'Curl')
                obj.Cache('Curl') = bct.dec.d1(obj);
            end
            op = obj.Cache('Curl');
        end
        
        % ---- Differential operator methods (apply to signals) ----
        
        function a1 = gradient(obj, f0)
            %gradient Compute gradient of scalar field (0-form → 1-form)
            %
            % Syntax:
            %   a1 = dec.gradient(f0)
            %
            % Inputs:
            %   f0 - [V×1] scalar field on vertices
            %
            % Returns:
            %   a1 - [E×1] edge-based gradient (1-form)
            %
            % Note: Delegates to bct.dec.gradient
            %
            % See also: bct.dec.gradient, divergence, curl
            
            arguments
                obj (1,1) bct.DEC
                f0 (:,1) double
            end
            
            a1 = bct.dec.gradient(obj, f0);
        end
        
        function f0 = divergence(obj, a1)
            %divergence Compute divergence of vector field (1-form → 0-form)
            %
            % Syntax:
            %   f0 = dec.divergence(a1)
            %
            % Inputs:
            %   a1 - [E×1] edge-based vector field (1-form)
            %
            % Returns:
            %   f0 - [V×1] vertex-based divergence (0-form)
            %
            % Note: Delegates to bct.dec.divergence
            %
            % See also: bct.dec.divergence, gradient, curl
            
            arguments
                obj (1,1) bct.DEC
                a1 (:,1) double
            end
            
            f0 = bct.dec.divergence(obj, a1);
        end
        
        function a2 = curl(obj, a1)
            %curl Compute curl of vector field (1-form → 2-form)
            %
            % Syntax:
            %   a2 = dec.curl(a1)
            %
            % Inputs:
            %   a1 - [E×1] edge-based vector field (1-form)
            %
            % Returns:
            %   a2 - [F×1] face-based curl (2-form / scalar curl)
            %
            % Note: Delegates to bct.dec.curl
            %
            % See also: bct.dec.curl, gradient, divergence
            
            arguments
                obj (1,1) bct.DEC
                a1 (:,1) double
            end
            
            a2 = bct.dec.curl(obj, a1);
        end
    end

    methods (Access = private)
        function val = getBackendField_(obj, fieldName)
            %getBackendField_ Safe backend field accessor with a clear error
            %
            % This does not compute anything; it only retrieves a backend
            % property/field. Supports both struct-like and object properties.

            % NOTE: No caching by default for primitives (cheap). If needed,
            % you may add caching here, but only for retrieval, not computation.

            B = obj.Backend;

            % Try property access first
            if isprop(B, fieldName)
                val = B.(fieldName);
                return;
            end

            % Fallback: some backends expose as struct fields
            if isstruct(B) && isfield(B, fieldName)
                val = B.(fieldName);
                return;
            end

            error("bct:DEC:BackendFieldMissing", ...
                "DECLab backend does not expose required field '%s'.", fieldName);
        end
    end
end
