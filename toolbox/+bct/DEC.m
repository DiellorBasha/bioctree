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

    properties (Access = private)
        Cache (1,1) containers.Map    % Optional cache of backend-derived objects
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
