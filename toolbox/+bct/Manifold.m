classdef Manifold < handle
    %MANIFOLD  Geometric substrate for surface-based analysis
    %
    % Defines geometry, topology, and metric. Provides access to
    % FEM, DEC, and Graph representations via ports.
    %
    % Design principles (from ManifoldContract):
    %   - Manifold owns: Topology, Embedding, Metric, Intrinsic differential structure
    %   - FEM, DEC, Graph are views accessed through ports (not stored properties)
    %   - Immutable geometry, mutable representations
    %   - No analysis, filters, brushes, spectral pipelines, or UI state
    %
    % Usage:
    %   % Construction
    %   M = bct.Manifold(struct('V', V, 'F', F));
    %   
    %   % Access representations via ports
    %   fem = M.FEM();
    %   dec = M.DEC();
    %   graph = M.Graph();
    %
    % See also: bct.Graph, bct.Operator, DiscreteExteriorCalculus

    properties (SetAccess = private)
        Vertices         % [N×3] vertex coordinates (immutable)
        Faces            % [M×3] face connectivity (immutable)
        Edges            % [E×2] edge connectivity (derived from faces)
        ID               % Unique identifier for compatibility tracking
    end

    properties (Access = private)
        Cache            % containers.Map for lazy representation creation
        Geometry         % Struct for cached geometric computations (frames, etc.)
        CachedMass       % Cached mass matrix (computed on first access)
        CachedStiffness  % Cached stiffness/cotangent matrix (computed on first access)
        CachedMassType   % Type of mass matrix cached ('voronoi', 'barycentric', 'full')
        CachedEigen      % Cached eigenmode structure (values, vectors, metadata)
        CachedGeometry   % Cached full geometry structure (from bct.manifold.geometry)
        CachedTopology   % Cached full topology structure (from bct.manifold.topology)
    end

    methods
        % ===============================================================
        % CONSTRUCTOR
        % ===============================================================
        
        function obj = Manifold(varargin)
            %MANIFOLD Constructor for Manifold domain
            %
            % Syntax:
            %   M = bct.Manifold(meshStruct)
            %   M = bct.Manifold(V, F)
            %
            % Inputs:
            %   meshStruct - Structure with fields:
            %                .V or .Vertices - [N×3] vertex coordinates
            %                .F or .Faces    - [M×3] face connectivity
            %   V          - [N×3] vertex coordinates
            %   F          - [M×3] face connectivity
            %
            % Outputs:
            %   M - Manifold object (immutable geometry)
            %
            % Examples:
            %   % From struct
            %   data = load('mesh.mat');
            %   M = bct.Manifold(struct('V', data.V, 'F', data.F));
            %
            %   % From V, F directly
            %   M = bct.Manifold(V, F);
            
            % Parse inputs
            if nargin == 1 && isstruct(varargin{1})
                % Struct interface: M = Manifold(meshStruct)
                meshStruct = varargin{1};
                
                % Extract geometry (support both old and new naming)
                if isfield(meshStruct, 'Vertices')
                    obj.Vertices = meshStruct.Vertices;
                elseif isfield(meshStruct, 'V')
                    obj.Vertices = meshStruct.V;
                else
                    error('bct:Manifold:MissingVertices', 'meshStruct must have Vertices or V field');
                end

                if isfield(meshStruct, 'Faces')
                    obj.Faces = meshStruct.Faces;
                elseif isfield(meshStruct, 'F')
                    obj.Faces = meshStruct.F;
                else
                    error('bct:Manifold:MissingFaces', 'meshStruct must have Faces or F field');
                end
                
            elseif nargin == 2
                % Direct interface: M = Manifold(V, F)
                obj.Vertices = varargin{1};
                obj.Faces = varargin{2};
                
                % Validate inputs
                if isempty(obj.Vertices)
                    error('MATLAB:invalidInput', 'Vertices cannot be empty');
                end
                if isempty(obj.Faces)
                    error('MATLAB:invalidInput', 'Faces cannot be empty');
                end
                if size(obj.Vertices, 2) ~= 3
                    error('MATLAB:invalidInput', 'Vertices must be N×3 array');
                end
                if size(obj.Faces, 2) ~= 3
                    error('MATLAB:invalidInput', 'Faces must be M×3 array');
                end
            else
                error('bct:Manifold:InvalidArguments', ...
                    'Usage: Manifold(meshStruct) or Manifold(V, F)');
            end
            
            % Extract or compute edges
            obj.Edges = obj.computeEdges();
            
            % Generate unique ID for this manifold
            obj.ID = string(java.util.UUID.randomUUID());

            % Initialize cache for representations
            obj.Cache = containers.Map('KeyType','char','ValueType','any');
            
            % Initialize geometry cache for frames
            obj.Geometry = struct();
            
            % Initialize FEM matrix cache
            obj.CachedMass = [];
            obj.CachedStiffness = [];
            obj.CachedMassType = "";
            
            % Initialize eigenmode cache
            obj.CachedEigen = struct();
        end

        % ===============================================================
        % REPRESENTATION PORTS (FEM, DEC, Graph)
        % ===============================================================
        
        function fem = FEM(obj)
            %FEM Get FEM representation struct (lazy creation with caching)
            %
            % Syntax:
            %   fem = M.FEM()
            %
            % Outputs:
            %   fem - Struct with fields:
            %         * V - Vertices
            %         * F - Faces
            %         * G - Gradient operator (lazy-computed)
            %         * D - Divergence operator (lazy-computed)
            %         * Manifold - Reference to parent Manifold
            %
            % Note: 
            %   - First call creates FEM struct, subsequent calls return cached version
            %   - Gradient/Divergence matrices computed on first use and cached
            %   - Requires gptoolbox functions (grad, div) on path
            %
            % See also: bct.runtime.operators.femGradient, bct.runtime.operators.femDivergence
            
            if ~isKey(obj.Cache, 'FEM')
                fem = struct();
                fem.V = obj.Vertices;
                fem.F = obj.Faces;
                fem.Manifold = obj;
                fem.G = [];  % Lazy-computed gradient matrix
                fem.D = [];  % Lazy-computed divergence matrix
                obj.Cache('FEM') = fem;
            end
            fem = obj.Cache('FEM');
        end

        function dec = DEC(obj)
            %DEC Get DECLab DiscreteExteriorCalculus backend (lazy creation with caching)
            %
            % Syntax:
            %   dec = M.DEC()
            %
            % Outputs:
            %   dec - DiscreteExteriorCalculus (DECLab backend)
            %
            % Note: 
            %   - First call creates DEC backend, subsequent calls return cached version
            %   - Returns DiscreteExteriorCalculus directly (not bct.DEC wrapper)
            %   - Use with bct.runtime.operators() for DEC operations
            %
            % See also: DiscreteExteriorCalculus, bct.runtime.operators
            
            if ~isKey(obj.Cache, 'DEC')
                % Check for DECLab availability
                if exist("DiscreteExteriorCalculus", "class") ~= 8
                    error("bct:MissingDependency", ...
                        ['DECLab not found on MATLAB path (DiscreteExteriorCalculus missing). ' ...
                         'Add external/DECLab to your path.']);
                end
                
                F = double(obj.Faces);
                V = double(obj.Vertices);
                obj.Cache('DEC') = DiscreteExteriorCalculus(F, V);
            end
            dec = obj.Cache('DEC');
        end
        
        function op = d0(obj)
            %D0 Get exterior derivative operator d0: C⁰ → C¹
            %
            % Syntax:
            %   op = M.d0()
            %
            % Outputs:
            %   op - bct.Operator wrapping the d0 matrix
            %
            % Description:
            %   Returns the exterior derivative operator that maps 0-forms
            %   (scalar fields on vertices) to 1-forms (fields on edges).
            %   This is the discrete differential operator from DECLab.
            %
            %   Mathematical properties:
            %   - d0 maps vertex values to edge circulations
            %   - Size: [numEdges × numVertices]
            %   - d1 ∘ d0 = 0 (exactness: boundary of boundary is zero)
            %
            % Examples:
            %   % Get d0 operator
            %   M = bct.Manifold(V, F);
            %   d0 = M.d0();
            %
            %   % Apply to scalar field (0-form)
            %   omega0 = rand(M.numVertices(), 1);
            %   omega1 = d0 * omega0;  % Result is 1-form on edges
            %
            %   % Check exactness: d1 ∘ d0 = 0
            %   d1 = M.d1();
            %   d1d0 = d1 * d0;
            %   norm(d1d0.Matrix, 'fro')  % Should be ~0
            %
            % See also: d1, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.d0, ...
                'ID', "d0", ...
                'Name', "Exterior Derivative (0→1)", ...
                'Domain', "dec", ...
                'InputType', "0-form", ...
                'OutputType', "1-form");
        end
        
        function op = d1(obj)
            %D1 Get exterior derivative operator d1: C¹ → C²
            %
            % Syntax:
            %   op = M.d1()
            %
            % Outputs:
            %   op - bct.Operator wrapping the d1 matrix
            %
            % Description:
            %   Returns the exterior derivative operator that maps 1-forms
            %   (fields on edges) to 2-forms (fields on faces).
            %   This is the discrete differential operator from DECLab.
            %
            %   Mathematical properties:
            %   - d1 maps edge circulations to face fluxes
            %   - Size: [numFaces × numEdges]
            %   - d1 ∘ d0 = 0 (exactness: boundary of boundary is zero)
            %
            % Examples:
            %   % Get d1 operator
            %   M = bct.Manifold(V, F);
            %   d1 = M.d1();
            %
            %   % Apply to 1-form (edge field)
            %   omega1 = rand(M.numEdges(), 1);
            %   omega2 = d1 * omega1;  % Result is 2-form on faces
            %
            %   % Check exactness: d1 ∘ d0 = 0
            %   d0 = M.d0();
            %   d1d0 = d1 * d0;
            %   norm(d1d0.Matrix, 'fro')  % Should be ~0
            %
            % See also: d0, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.d1, ...
                'ID', "d1", ...
                'Name', "Exterior Derivative (1→2)", ...
                'Domain', "dec", ...
                'InputType', "1-form", ...
                'OutputType', "2-form");
        end
        
        function op = dd0(obj)
            %DD0 Get codifferential operator dd0: C¹ → C⁰ (dual of d0)
            %
            % Syntax:
            %   op = M.dd0()
            %
            % Outputs:
            %   op - bct.Operator wrapping the dd0 matrix
            %
            % Description:
            %   Returns the codifferential (adjoint of exterior derivative) that
            %   maps 1-forms on dual edges to 0-forms on dual vertices.
            %   This is the dual exterior derivative from DECLab.
            %
            %   Mathematical properties:
            %   - dd0 is the formal adjoint of d0 on dual complex
            %   - Size: [numFaces × numEdges]
            %   - Related to divergence on dual mesh
            %
            % Examples:
            %   % Get dd0 operator
            %   M = bct.Manifold(V, F);
            %   dd0 = M.dd0();
            %
            %   % Apply to 1-form on dual edges
            %   omega1_dual = rand(M.numEdges(), 1);
            %   omega0_dual = dd0 * omega1_dual;
            %
            % See also: d0, dd1, hd0, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.dd0, ...
                'ID', "dd0", ...
                'Name', "Codifferential (dual 0→1)", ...
                'Domain', "dec", ...
                'InputType', "1-form (dual)", ...
                'OutputType', "0-form (dual)");
        end
        
        function op = dd1(obj)
            %DD1 Get codifferential operator dd1: C² → C¹ (dual of d1)
            %
            % Syntax:
            %   op = M.dd1()
            %
            % Outputs:
            %   op - bct.Operator wrapping the dd1 matrix
            %
            % Description:
            %   Returns the codifferential (adjoint of exterior derivative) that
            %   maps 2-forms on dual faces to 1-forms on dual edges.
            %   This is the dual exterior derivative from DECLab.
            %
            %   Mathematical properties:
            %   - dd1 is the formal adjoint of d1 on dual complex
            %   - Size: [numEdges × numVertices]
            %   - Related to curl on dual mesh
            %
            % Examples:
            %   % Get dd1 operator
            %   M = bct.Manifold(V, F);
            %   dd1 = M.dd1();
            %
            %   % Apply to 2-form on dual faces
            %   omega2_dual = rand(M.numVertices(), 1);
            %   omega1_dual = dd1 * omega2_dual;
            %
            % See also: d1, dd0, hd1, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.dd1, ...
                'ID', "dd1", ...
                'Name', "Codifferential (dual 1→2)", ...
                'Domain', "dec", ...
                'InputType', "2-form (dual)", ...
                'OutputType', "1-form (dual)");
        end
        
        function op = hd0(obj)
            %HD0 Get Hodge star operator ⋆₀: C⁰ → C²
            %
            % Syntax:
            %   op = M.hd0()
            %
            % Outputs:
            %   op - bct.Operator wrapping the hd0 matrix
            %
            % Description:
            %   Returns the Hodge star operator that maps primal 0-forms
            %   (vertex values) to dual 2-forms (face values on dual mesh).
            %   The Hodge star is a metric-dependent isomorphism between
            %   k-forms and (n-k)-forms.
            %
            %   Mathematical properties:
            %   - Diagonal matrix with dual cell areas
            %   - Size: [numVertices × numVertices]
            %   - Relates primal and dual complexes via metric
            %
            % Examples:
            %   % Get Hodge star ⋆₀
            %   M = bct.Manifold(V, F);
            %   star0 = M.hd0();
            %
            %   % Apply to 0-form
            %   omega0 = rand(M.numVertices(), 1);
            %   omega2_dual = star0 * omega0;
            %
            % See also: hd1, hd2, hdd0, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.hd0, ...
                'ID', "hd0", ...
                'Name', "Hodge Star ⋆₀", ...
                'Domain', "dec", ...
                'InputType', "0-form (primal)", ...
                'OutputType', "2-form (dual)");
        end
        
        function op = hd1(obj)
            %HD1 Get Hodge star operator ⋆₁: C¹ → C¹
            %
            % Syntax:
            %   op = M.hd1()
            %
            % Outputs:
            %   op - bct.Operator wrapping the hd1 matrix
            %
            % Description:
            %   Returns the Hodge star operator that maps primal 1-forms
            %   (edge values) to dual 1-forms (dual edge values).
            %   For 1-forms on 2-manifolds, the Hodge star maps to 1-forms.
            %
            %   Mathematical properties:
            %   - Maps primal edges to dual edges
            %   - Size: [numEdges × numEdges]
            %   - Diagonal matrix with dual edge lengths
            %
            % Examples:
            %   % Get Hodge star ⋆₁
            %   M = bct.Manifold(V, F);
            %   star1 = M.hd1();
            %
            %   % Apply to 1-form
            %   omega1 = rand(M.numEdges(), 1);
            %   omega1_dual = star1 * omega1;
            %
            % See also: hd0, hd2, hdd1, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.hd1, ...
                'ID', "hd1", ...
                'Name', "Hodge Star ⋆₁", ...
                'Domain', "dec", ...
                'InputType', "1-form (primal)", ...
                'OutputType', "1-form (dual)");
        end
        
        function op = hd2(obj)
            %HD2 Get Hodge star operator ⋆₂: C² → C⁰
            %
            % Syntax:
            %   op = M.hd2()
            %
            % Outputs:
            %   op - bct.Operator wrapping the hd2 matrix
            %
            % Description:
            %   Returns the Hodge star operator that maps primal 2-forms
            %   (face values) to dual 0-forms (vertex values on dual mesh).
            %   Complements ⋆₀ for the full Hodge decomposition.
            %
            %   Mathematical properties:
            %   - Diagonal matrix with dual vertex areas
            %   - Size: [numFaces × numFaces]
            %   - ⋆₂⋆₀ = identity (up to orientation)
            %
            % Examples:
            %   % Get Hodge star ⋆₂
            %   M = bct.Manifold(V, F);
            %   star2 = M.hd2();
            %
            %   % Apply to 2-form
            %   omega2 = rand(M.numFaces(), 1);
            %   omega0_dual = star2 * omega2;
            %
            % See also: hd0, hd1, hdd2, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.hd2, ...
                'ID', "hd2", ...
                'Name', "Hodge Star ⋆₂", ...
                'Domain', "dec", ...
                'InputType', "2-form (primal)", ...
                'OutputType', "0-form (dual)");
        end
        
        function op = hdd0(obj)
            %HDD0 Get inverse Hodge star operator ⋆₀⁻¹: C² → C⁰
            %
            % Syntax:
            %   op = M.hdd0()
            %
            % Outputs:
            %   op - bct.Operator wrapping the hdd0 matrix
            %
            % Description:
            %   Returns the inverse Hodge star operator that maps dual 2-forms
            %   to primal 0-forms. This is the inverse of ⋆₀.
            %
            %   Mathematical properties:
            %   - Inverse of hd0
            %   - Size: [numVertices × numVertices]
            %   - Diagonal matrix with inverse dual areas
            %
            % Examples:
            %   % Get inverse Hodge star ⋆₀⁻¹
            %   M = bct.Manifold(V, F);
            %   invstar0 = M.hdd0();
            %
            %   % Verify inverse relationship
            %   star0 = M.hd0();
            %   omega0 = rand(M.numVertices(), 1);
            %   recovered = invstar0 * (star0 * omega0);
            %   norm(omega0 - recovered)  % Should be ~0
            %
            % See also: hd0, hdd1, hdd2, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.hdd0, ...
                'ID', "hdd0", ...
                'Name', "Inverse Hodge Star ⋆₀⁻¹", ...
                'Domain', "dec", ...
                'InputType', "2-form (dual)", ...
                'OutputType', "0-form (primal)");
        end
        
        function op = hdd1(obj)
            %HDD1 Get inverse Hodge star operator ⋆₁⁻¹: C¹ → C¹
            %
            % Syntax:
            %   op = M.hdd1()
            %
            % Outputs:
            %   op - bct.Operator wrapping the hdd1 matrix
            %
            % Description:
            %   Returns the inverse Hodge star operator that maps dual 1-forms
            %   to primal 1-forms. This is the inverse of ⋆₁.
            %
            %   Mathematical properties:
            %   - Inverse of hd1
            %   - Size: [numEdges × numEdges]
            %   - Diagonal matrix with inverse dual edge lengths
            %
            % Examples:
            %   % Get inverse Hodge star ⋆₁⁻¹
            %   M = bct.Manifold(V, F);
            %   invstar1 = M.hdd1();
            %
            %   % Verify inverse relationship
            %   star1 = M.hd1();
            %   omega1 = rand(M.numEdges(), 1);
            %   recovered = invstar1 * (star1 * omega1);
            %   norm(omega1 - recovered)  % Should be ~0
            %
            % See also: hd1, hdd0, hdd2, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.hdd1, ...
                'ID', "hdd1", ...
                'Name', "Inverse Hodge Star ⋆₁⁻¹", ...
                'Domain', "dec", ...
                'InputType', "1-form (dual)", ...
                'OutputType', "1-form (primal)");
        end
        
        function op = hdd2(obj)
            %HDD2 Get inverse Hodge star operator ⋆₂⁻¹: C⁰ → C²
            %
            % Syntax:
            %   op = M.hdd2()
            %
            % Outputs:
            %   op - bct.Operator wrapping the hdd2 matrix
            %
            % Description:
            %   Returns the inverse Hodge star operator that maps dual 0-forms
            %   to primal 2-forms. This is the inverse of ⋆₂.
            %
            %   Mathematical properties:
            %   - Inverse of hd2
            %   - Size: [numFaces × numFaces]
            %   - Diagonal matrix with inverse dual vertex areas
            %
            % Examples:
            %   % Get inverse Hodge star ⋆₂⁻¹
            %   M = bct.Manifold(V, F);
            %   invstar2 = M.hdd2();
            %
            %   % Verify inverse relationship
            %   star2 = M.hd2();
            %   omega2 = rand(M.numFaces(), 1);
            %   recovered = invstar2 * (star2 * omega2);
            %   norm(omega2 - recovered)  % Should be ~0
            %
            % See also: hd2, hdd0, hdd1, DEC, bct.Operator
            
            dec = obj.DEC();
            op = bct.Operator(obj, dec.hdd2, ...
                'ID', "hdd2", ...
                'Name', "Inverse Hodge Star ⋆₂⁻¹", ...
                'Domain', "dec", ...
                'InputType', "0-form (dual)", ...
                'OutputType', "2-form (primal)");
        end

        function M = massmatrix(obj, options)
            %MASSMATRIX Get or compute FEM mass matrix (lazy creation with caching)
            %
            % Syntax:
            %   M = manifold.massmatrix()
            %   M = manifold.massmatrix('Type', massType)
            %
            % Name-Value Parameters:
            %   Type - Mass matrix type (default: 'voronoi')
            %          'voronoi'     - Voronoi area cells (diagonal, default)
            %          'barycentric' - Equal area distribution (diagonal)
            %          'full'        - Consistent FEM mass matrix (sparse)
            %
            % Outputs:
            %   M - [N×N] sparse mass matrix
            %
            % Description:
            %   Returns the FEM mass matrix for the manifold. Matrix is computed
            %   on first call and cached for subsequent calls with same type.
            %   Different mass types are cached independently.
            %
            %   Note: Default 'voronoi' is recommended for discrete analysis.
            %
            % Examples:
            %   M = manifold.massmatrix();  % Default voronoi
            %   M = manifold.massmatrix('Type', 'barycentric');
            %
            % See also: bct.manifold.operator.mass, massmatrix, cotmatrix
            
            arguments
                obj
                options.Type (1,1) string {mustBeMember(options.Type, ["voronoi","barycentric","full"])} = "voronoi"
            end
            
            massType = options.Type;
            
            % Check if we have cached mass matrix of requested type
            if ~isempty(obj.CachedMass) && obj.CachedMassType == massType
                M = obj.CachedMass;
                return;
            end
            
            % Compute mass matrix using bct.manifold.operator.mass
            [~, M] = bct.manifold.operator.mass(obj, 'variant', massType);
            
            % Cache for future use
            obj.CachedMass = M;
            obj.CachedMassType = massType;
        end
        
        function K = cotmatrix(obj)
            %COTMATRIX Get or compute FEM stiffness/cotangent matrix (lazy creation with caching)
            %
            % Syntax:
            %   K = manifold.cotmatrix()
            %
            % Outputs:
            %   K - [N×N] sparse stiffness matrix (cotangent Laplacian)
            %
            % Description:
            %   Returns the FEM stiffness matrix (cotangent Laplacian) for the
            %   manifold. Matrix is computed on first call and cached for
            %   subsequent calls.
            %
            %   The cotangent matrix represents:
            %   - Discrete Dirichlet energy: E(u) = u' * K * u
            %   - Laplace-Beltrami operator: Δu = M^(-1) * K * u
            %   - Positive semidefinite form (λ ≥ 0)
            %
            % Examples:
            %   K = manifold.cotmatrix();
            %   energy = u' * K * u;  % Dirichlet energy
            %
            % See also: bct.manifold.operator.stiffness, massmatrix
            
            % Check if we have cached stiffness matrix
            if ~isempty(obj.CachedStiffness)
                K = obj.CachedStiffness;
                return;
            end
            
            % Compute stiffness matrix using bct.manifold.operator.stiffness
            [~, K] = bct.manifold.operator.stiffness(obj, ...
                'variant', 'cotan', ...
                'sign', 'positive', ...
                'symmetrize', true);
            
            % Cache for future use
            obj.CachedStiffness = K;
        end

        function g = Graph(obj)
            %GRAPH Get Graph representation (lazy creation with caching)
            %
            % Syntax:
            %   g = M.Graph()
            %
            % Outputs:
            %   g - bct.Graph object (navigation/topology)
            %
            % Note: First call creates Graph object, subsequent calls return cached version
            %
            % See also: bct.Graph
            
            if ~isKey(obj.Cache, 'Graph')
                obj.Cache('Graph') = bct.Graph(obj);
            end
            g = obj.Cache('Graph');
        end
        
        % ===============================================================
        % GEOMETRY CACHE (Internal accessor methods)
        % ===============================================================
        
        function geom = getGeometry(obj)
            %GETGEOMETRY Get geometry cache (internal use by bct.manifold.geometry.*)
            geom = obj.Geometry;
        end
        
        function setGeometry(obj, geom)
            %SETGEOMETRY Set geometry cache (internal use by bct.manifold.geometry.*)
            obj.Geometry = geom;
        end
        
        % ===============================================================
        % SPECTRAL ANALYSIS
        % ===============================================================
        
        function Eigen = eigenmodes(obj, varargin)
            %EIGENMODES Get or compute eigenmodes of Laplace-Beltrami operator
            %
            % Syntax:
            %   Eigen = M.eigenmodes()          % Get cached or compute with k=50
            %   Eigen = M.eigenmodes(k)         % Recompute with k modes
            %   Eigen = M.eigenmodes('k', k)    % Recompute with k modes (named)
            %   Eigen = M.eigenmodes('k', k, 'RemoveDC', false)  % Additional options
            %
            % Inputs:
            %   k - Number of eigenmodes (default: 50 if not cached)
            %
            % Optional Parameters:
            %   k         - Number of modes (can be positional or named)
            %   RemoveDC  - Remove DC mode (default: true)
            %   MassType  - Mass matrix type: 'voronoi' (default), 'barycentric', 'full'
            %   EigsOpts  - Additional eigs options (struct)
            %   Force     - Force recomputation even if cached (default: false)
            %
            % Outputs:
            %   Eigen - Structure with fields:
            %           .values    - [k×1] eigenvalues (sorted ascending)
            %           .vectors   - [N×k] eigenvectors (M-orthonormal)
            %           .k         - Number of modes
            %           .operator  - 'Laplace-Beltrami'
            %           .basis     - 'P1-FEM'
            %           .ordering  - 'ascending'
            %           .massType  - Mass matrix type used
            %           .removedDC - Whether DC mode was removed
            %
            % Description:
            %   Returns cached eigenmode structure if available, or computes
            %   using bct.manifold.eigenmodes() with specified parameters.
            %   Result is cached for future calls.
            %
            %   When called without arguments, returns cached Eigen structure
            %   or computes with default k=50 modes if not cached.
            %
            %   When called with arguments (k value), recomputes eigenmodes
            %   and updates the cache.
            %
            % Examples:
            %   % Get cached or compute with default k=50
            %   E = M.eigenmodes();
            %   lambda = E.values;
            %   U = E.vectors;
            %
            %   % Compute with 100 modes (updates cache)
            %   E = M.eigenmodes(100);
            %
            %   % Named parameter
            %   E = M.eigenmodes('k', 100);
            %
            %   % With additional options
            %   E = M.eigenmodes(100, 'MassType', 'barycentric');
            %
            %   % Force recomputation
            %   E = M.eigenmodes('Force', true);
            %
            % See also: bct.manifold.eigenmodes, eigensolve
            
            % Parse input arguments
            p = inputParser;
            p.addOptional('k', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
            p.addParameter('RemoveDC', true, @islogical);
            p.addParameter('MassType', "voronoi", @(x) isstring(x) || ischar(x));
            p.addParameter('EigsOpts', struct(), @isstruct);
            p.addParameter('Force', false, @islogical);
            p.parse(varargin{:});
            
            k_requested = p.Results.k;
            removeDC = p.Results.RemoveDC;
            massType = string(p.Results.MassType);
            eigsOpts = p.Results.EigsOpts;
            force = p.Results.Force;
            
            % Determine if we need to compute
            needsCompute = false;
            
            if force
                % Forced recomputation
                needsCompute = true;
                if isempty(k_requested)
                    % Use cached k if available, otherwise default
                    if isfield(obj.CachedEigen, 'k') && ~isempty(obj.CachedEigen.k)
                        k_requested = obj.CachedEigen.k;
                    else
                        k_requested = 50;  % Default
                    end
                end
            elseif ~isempty(k_requested)
                % k specified, need to recompute
                needsCompute = true;
            elseif isempty(fieldnames(obj.CachedEigen))
                % No cache exists, compute with default k=50
                k_requested = 50;
                needsCompute = true;
            else
                % Return cached
                Eigen = obj.CachedEigen;
                return;
            end
            
            % Compute eigenmodes using bct.manifold.eigenmodes
            [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(...
                obj, k_requested, ...
                'RemoveDC', removeDC, ...
                'MassType', massType, ...
                'EigsOpts', eigsOpts);
            
            % Build Eigen structure
            Eigen = struct();
            Eigen.values = eigenvalues;
            Eigen.vectors = eigenvectors;
            Eigen.k = length(eigenvalues);
            Eigen.operator = "Laplace-Beltrami";
            Eigen.basis = "P1-FEM";
            Eigen.ordering = "ascending";
            Eigen.massType = massType;
            Eigen.removedDC = removeDC;
            
            % Cache for future use
            obj.CachedEigen = Eigen;
        end

        function [Psi, Lambda] = eigensolve(obj, k, options)
            %EIGENSOLVE Compute eigenpairs of Laplace-Beltrami operator
            %
            % WARNING: DEPRECATED - Use M.eigenmodes() instead
            %
            %   This method is deprecated and will be removed in a future release.
            %   Use M.eigenmodes() for direct eigenmode computation:
            %
            %   Old: [Psi, Lambda] = M.eigensolve(100);
            %   New: E = M.eigenmodes(100); Psi = E.vectors; Lambda = E.values;
            %
            % Syntax:
            %   [Psi, Lambda] = M.eigensolve(k)
            %   [Psi, Lambda] = M.eigensolve(k, 'Method', 'FEM')
            %   [Psi, Lambda] = M.eigensolve(k, 'Force', true)
            %
            % Inputs:
            %   k - Number of eigenmodes to compute
            %
            % Optional Parameters:
            %   Method - Eigensolve method: 'FEM' (default)
            %            Future: 'DEC', 'Graph'
            %   Force  - If true, recompute even if cached (default: false)
            %
            % Outputs:
            %   Psi    - [N×k] matrix of eigenvectors (columns are eigenmodes)
            %   Lambda - [k×1] vector of eigenvalues (spatial frequencies)
            %
            % Note: Currently only 'FEM' method is implemented. This delegates
            %       to FEM().eigenpairs() for computation.
            %
            % Examples:
            %   % Compute first 100 eigenmodes
            %   [Psi, Lambda] = M.eigensolve(100);
            %
            %   % Use FEM method explicitly
            %   [Psi, Lambda] = M.eigensolve(100, 'Method', 'FEM');
            %
            % See also: bct.Manifold.eigenmodes, bct.manifold.eigen.solve
            
            arguments
                obj
                k (1,1) double {mustBePositive, mustBeInteger}
                options.Method (1,1) string {mustBeMember(options.Method, ["FEM"])} = "FEM"
                options.Force (1,1) logical = false
            end
            
            % Deprecation warning
            warning('bct:Manifold:eigensolve:Deprecated', ...
                sprintf(['M.eigensolve() is deprecated and will be removed in a future release.\n' ...
                         'Use M.eigenmodes() instead:\n' ...
                         '  Old: [Psi, Lambda] = M.eigensolve(%d);\n' ...
                         '  New: E = M.eigenmodes(%d); Psi = E.vectors; Lambda = E.values;'], ...
                        k, k));
            
            % Delegate to appropriate method
            switch options.Method
                case "FEM"
                    % Delegate to FEM eigenpairs method
                    fem = obj.FEM();
                    E = fem.eigenpairs(k, 'Force', options.Force);
                    
                    % Extract eigenvectors and eigenvalues
                    Psi = E.Vectors;
                    Lambda = E.Values;
                    
                otherwise
                    error('bct:Manifold:UnsupportedMethod', ...
                          'Method "%s" not yet implemented. Currently only "FEM" is supported.', ...
                          options.Method);
            end
        end
        
        % ===============================================================
        % GEOMETRIC QUERIES (thin delegations)
        % ===============================================================
        
        function N = numVertices(obj)
            %NUMVERTICES Get number of vertices
            N = size(obj.Vertices, 1);
        end

        function M = numFaces(obj)
            %NUMFACES Get number of faces
            M = size(obj.Faces, 1);
        end
        
        function E = numEdges(obj)
            %NUMEDGES Get number of edges
            E = size(obj.Edges, 1);
        end
        
        function A = adjacency(obj)
            %ADJACENCY Compute binary adjacency matrix from faces
            %
            % Syntax:
            %   A = M.adjacency()
            %
            % Outputs:
            %   A - [N×N] sparse logical adjacency matrix (symmetric, no self-loops)
            
            F = obj.Faces;
            if isempty(F)
                % No faces: return empty sparse matrix
                N = size(obj.Vertices, 1);
                A = sparse(N, N);
                return;
            end
            
            % Extract unique edges from faces
            e = unique(sort([F(:,[1 2]); F(:,[2 3]); F(:,[3 1])], 2), 'rows');
            
            % Build symmetric adjacency matrix
            N = size(obj.Vertices, 1);
            A = sparse(e(:,1), e(:,2), true, N, N);
            A = A + A.';                % Make symmetric
            A = A - diag(diag(A));      % Remove self-loops
            A = spones(A) > 0;          % Binary adjacency
        end
        
        function bbox = boundingBox(obj)
            %BOUNDINGBOX Get axis-aligned bounding box
            %
            % Syntax:
            %   bbox = M.boundingBox()
            %
            % Outputs:
            %   bbox - [3×2] matrix: [xmin xmax; ymin ymax; zmin zmax]
            
            V = obj.Vertices;
            bbox = [min(V); max(V)].';
        end
        
        function C = centroids(obj)
            %CENTROIDS Compute face centroids
            %
            % Syntax:
            %   C = M.centroids()
            %
            % Outputs:
            %   C - [M×3] matrix of face centroids where M is number of faces
            %
            % Description:
            %   Computes the geometric center (centroid) of each triangular face
            %   as the average of its three vertex positions. This is a wrapper
            %   for bct.manifold.geometry.centroids().
            %
            % Examples:
            %   % Compute centroids
            %   M = bct.Manifold(V, F);
            %   C = M.centroids();
            %
            %   % Visualize centroids
            %   C = M.centroids();
            %   plot3(C(:,1), C(:,2), C(:,3), 'r.', 'MarkerSize', 10);
            %
            % See also: bct.manifold.geometry.centroids
            
            C = bct.manifold.geometry.centroids(obj);
        end
        
        function N = normals(obj, type)
            %NORMALS Compute vertex or face normals
            %
            % Syntax:
            %   N = M.normals()
            %   N = M.normals(Type)
            %
            % Inputs:
            %   Type - 'Vertex' (default) or 'Face'
            %
            % Outputs:
            %   N - [N×3] vertex normals or [M×3] face normals
            %
            % Description:
            %   Computes vertex or face normals using MATLAB's surfaceMesh object.
            %   By default returns vertex normals. Specify 'Face' to get face normals.
            %   This is a wrapper for bct.manifold.geometry.normals().
            %
            % Examples:
            %   % Compute vertex normals (default)
            %   M = bct.Manifold(V, F);
            %   VN = M.normals();
            %
            %   % Compute face normals
            %   FN = M.normals('Face');
            %
            %   % Visualize vertex normals
            %   VN = M.normals();
            %   quiver3(V(:,1), V(:,2), V(:,3), VN(:,1), VN(:,2), VN(:,3), 0.5);
            %
            % See also: bct.manifold.geometry.normals, centroids
            
            arguments
                obj
                type {mustBeTextScalar} = 'Vertex'
            end
            
            N = bct.manifold.geometry.normals(obj, type);
        end
        
        function [N, e1, e2] = tangents(obj, options)
            %TANGENTS Compute orthonormal tangent frame for each face or vertex
            %
            % Syntax:
            %   [N, e1, e2] = M.tangents()
            %   [N, e1, e2] = M.tangents('Domain', 'face')    % default
            %   [N, e1, e2] = M.tangents('Domain', 'vertex')
            %
            % Name-Value:
            %   'Domain' - 'face' (default) or 'vertex'
            %
            % Outputs:
            %   N  - normals:
            %        * face domain:   [Nf×3] face normals (unit)
            %        * vertex domain: [Nv×3] vertex normals (unit)
            %   e1 - first tangent basis vector (same size as N)
            %   e2 - second tangent basis vector (same size as N)
            %
            % Description:
            %   Computes an orthonormal coordinate frame {e1, e2, N} for each face or
            %   vertex. The frame is right-handed with:
            %   - N: face/vertex normal
            %   - e1: first tangent basis vector (orthogonal to N)
            %   - e2: second tangent basis vector (orthogonal to both N and e1)
            %
            %   Face tangents are computed per triangle using the first edge.
            %   Vertex tangents use a robust reference axis projection method.
            %   This is a wrapper for bct.manifold.geometry.tangents().
            %
            % Examples:
            %   % Face tangent frame
            %   M = bct.Manifold(V, F);
            %   [N, e1, e2] = M.tangents();
            %   [N, e1, e2] = M.tangents('Domain', 'face');
            %
            %   % Vertex tangent frame
            %   [N, e1, e2] = M.tangents('Domain', 'vertex');
            %
            %   % Visualize face tangent frame at centroids
            %   C = M.centroids();
            %   [N, e1, e2] = M.tangents('Domain', 'face');
            %   quiver3(C(:,1), C(:,2), C(:,3), e1(:,1), e1(:,2), e1(:,3), 0.5, 'r');
            %   hold on;
            %   quiver3(C(:,1), C(:,2), C(:,3), e2(:,1), e2(:,2), e2(:,3), 0.5, 'g');
            %   quiver3(C(:,1), C(:,2), C(:,3), N(:,1), N(:,2), N(:,3), 0.5, 'b');
            %
            %   % Visualize vertex tangent frame
            %   [N, e1, e2] = M.tangents('Domain', 'vertex');
            %   quiver3(M.Vertices(:,1), M.Vertices(:,2), M.Vertices(:,3), ...
            %           e1(:,1), e1(:,2), e1(:,3), 0.5, 'r');
            %
            % See also: bct.manifold.geometry.tangents, normals, centroids
            
            arguments
                obj bct.Manifold
                options.Domain {mustBeMember(options.Domain, ["face", "vertex", "Face", "Vertex"])} = "face"
            end
            
            [N, e1, e2] = bct.manifold.geometry.tangents(obj, 'Domain', options.Domain);
        end
        
        function geom = geometry(obj, varargin)
            %GEOMETRY Compute and cache all geometric properties
            %
            % Syntax:
            %   geom = M.geometry()
            %   geom = M.geometry(Name, Value)
            %
            % Name-Value Arguments:
            %   'NormalType'    - 'vertex' (default) or 'face'
            %   'TangentDomain' - 'face' (default) or 'vertex'
            %   'ForceFrame'    - false (default) or true to force recomputation
            %   'Force'         - false (default) or true to force full recomputation
            %
            % Outputs:
            %   geom - Structure with fields:
            %     .centroids - [nF×3] Face centroids
            %     .normals   - [nV×3] or [nF×3] Normal vectors
            %     .tangents  - Structure with N, e1, e2 tangent frames
            %     .frame     - Cached orthonormal frame structure
            %     .cotan     - [nF×3] Cotangent values per face
            %
            % Description:
            %   Computes all geometric properties of the manifold and caches
            %   the result for future calls. This is a wrapper for
            %   bct.manifold.geometry() that handles caching.
            %
            %   On first call, computes all geometry. Subsequent calls return
            %   the cached result unless 'Force' is true.
            %
            % Examples:
            %   % Compute and cache all geometry
            %   M = bct.Manifold(V, F);
            %   geom = M.geometry();
            %   
            %   % Access individual properties
            %   C = geom.centroids;
            %   N = geom.normals;
            %   T1 = geom.tangents.e1;
            %   
            %   % Force recomputation
            %   geom = M.geometry('Force', true);
            %   
            %   % Compute with custom parameters
            %   geom = M.geometry('NormalType', 'face', 'TangentDomain', 'vertex');
            %
            % See also: bct.manifold.geometry, centroids, normals, tangents
            
            % Parse inputs
            p = inputParser;
            p.FunctionName = 'bct.Manifold.geometry';
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'NormalType', 'vertex', @(x) ischar(x) || isstring(x));
            addParameter(p, 'TangentDomain', 'face', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ForceFrame', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if we have cached geometry and not forcing recomputation
            if ~force && ~isempty(obj.CachedGeometry)
                geom = obj.CachedGeometry;
                return;
            end
            
            % Compute all geometry using bct.manifold.geometry
            geom = bct.manifold.geometry(obj, ...
                'NormalType', p.Results.NormalType, ...
                'TangentDomain', p.Results.TangentDomain, ...
                'ForceFrame', p.Results.ForceFrame);
            
            % Cache the result
            obj.CachedGeometry = geom;
        end
        
        function topo = topology(obj, varargin)
            %TOPOLOGY Compute and cache all topological properties
            %
            % Syntax:
            %   topo = M.topology()
            %   topo = M.topology('Force', true)
            %
            % Name-Value Arguments:
            %   'Force' - false (default) or true to force recomputation
            %
            % Outputs:
            %   topo - Structure with fields:
            %     .edges     - [nE×2] Unique undirected edges
            %     .adjacency - [N×N] Sparse binary adjacency matrix
            %     .halfedge  - Halfedge data structure with navigation
            %
            % Description:
            %   Computes all topological properties of the manifold and caches
            %   the result for future calls. This is a wrapper for
            %   bct.manifold.topology() that handles caching.
            %
            %   Topology is coordinate-free and depends only on face
            %   connectivity. On first call, computes all topology. Subsequent
            %   calls return the cached result unless 'Force' is true.
            %
            % Examples:
            %   % Compute and cache all topology
            %   M = bct.Manifold(V, F);
            %   topo = M.topology();
            %   
            %   % Access individual properties
            %   E = topo.edges;          % [nE×2] edge list
            %   A = topo.adjacency;      % [N×N] adjacency matrix
            %   he = topo.halfedge;      % Halfedge structure
            %   
            %   % Navigate mesh using halfedge
            %   h = 1;  % First halfedge
            %   next_h = topo.halfedge.next(h);
            %   twin_h = topo.halfedge.twin(h);
            %   
            %   % Force recomputation
            %   topo = M.topology('Force', true);
            %
            % See also: bct.manifold.topology, geometry
            
            % Parse inputs
            p = inputParser;
            p.FunctionName = 'bct.Manifold.topology';
            addParameter(p, 'Force', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if we have cached topology and not forcing recomputation
            if ~force && ~isempty(obj.CachedTopology)
                topo = obj.CachedTopology;
                return;
            end
            
            % Compute all topology using bct.manifold.topology
            topo = bct.manifold.topology(obj);
            
            % Cache the result
            obj.CachedTopology = topo;
        end
        
        function write(obj, fileName, options)
            %WRITE Write Manifold to mesh file
            %
            % Syntax:
            %   M.write(fileName)
            %   M.write(fileName, 'Encoding', enc)
            %   M.write(fileName, 'Format', fmt)
            %
            % Supported File Formats:
            %   - .stl  - STL (STereoLithography) format
            %   - .ply  - PLY (Polygon File Format)
            %   - .obj  - OBJ (Wavefront) format
            %   - .glb  - GLB (Binary glTF)
            %   - .gltf - GLTF (GL Transmission Format)
            %   - .mat  - MATLAB data file (saves V and F variables)
            %   - .h5/.hdf5 - HDF5 format
            %
            % Inputs:
            %   fileName - String or char path for output file
            %
            % Optional Parameters:
            %   Encoding - 'binary' or 'ascii' (for formats that support it)
            %   Format   - Explicitly specify file format (auto-detected from extension)
            %
            % Examples:
            %   % Write to OBJ file
            %   M = bct.Manifold(V, F);
            %   M.write('output.obj');
            %
            %   % Write to GLB file
            %   M.write('model.glb');
            %
            %   % Write to HDF5 file
            %   M.write('mesh.h5');
            %
            %   % Write to STL with binary encoding
            %   M.write('output.stl', 'Encoding', 'binary');
            %
            % See also: bct.Manifold.read, bct.manifold.write
            
            arguments
                obj
                fileName string
                options.Encoding string = ""
                options.Format string = ""
            end
            
            % Delegate to bct.manifold.write function
            if options.Encoding ~= ""
                bct.manifold.write(obj, fileName, 'Encoding', options.Encoding, 'Format', options.Format);
            elseif options.Format ~= ""
                bct.manifold.write(obj, fileName, 'Format', options.Format);
            else
                bct.manifold.write(obj, fileName);
            end
        end
    end
    
    methods (Access = private)
        function E = computeEdges(obj)
            %COMPUTEEDGES Extract unique edges from faces
            %
            % Returns:
            %   E - [E×2] matrix of vertex indices forming edges
            %
            % Note: Manual unique() approach is faster than triangulation.edges()
            %       for large meshes (0.32s vs 0.50s on fsaverage6)
            
            F = obj.Faces;
            if isempty(F)
                E = zeros(0, 2);
                return;
            end
            
            % Extract all edges from triangular faces
            edges = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
            
            % Sort each edge so that (i,j) and (j,i) become the same
            edges = sort(edges, 2);
            
            % Get unique edges
            E = unique(edges, 'rows');
        end
    end

    methods (Static)
        function obj = read(fileName, options)
            %READ Load Manifold from mesh file
            %
            % Syntax:
            %   M = bct.Manifold.read(fileName)
            %   M = bct.Manifold.read(fileName, 'Format', fmt)
            %
            % Supported File Formats:
            %   - .stl  - STL (STereoLithography) format
            %   - .ply  - PLY (Polygon File Format)
            %   - .obj  - OBJ (Wavefront) format
            %   - .glb  - GLB (Binary glTF)
            %   - .gltf - GLTF (GL Transmission Format)
            %   - .mat  - MATLAB data file
            %   - .h5/.hdf5 - HDF5 format
            %
            % Inputs:
            %   fileName - String or char path to mesh file
            %
            % Optional Parameters:
            %   Format - Explicitly specify file format (auto-detected from extension)
            %
            % Outputs:
            %   M - Manifold object loaded from file
            %
            % Examples:
            %   % Read from OBJ file
            %   M = bct.Manifold.read('mesh.obj');
            %
            %   % Read from GLB file
            %   M = bct.Manifold.read('model.glb');
            %
            %   % Read from HDF5 file
            %   M = bct.Manifold.read('data.h5');
            %
            %   % Read MATLAB data file
            %   M = bct.Manifold.read('data/mesh/fsaverage_lh_pial.mat');
            %
            % See also: bct.Manifold.write, bct.manifold.read
            
            arguments
                fileName {mustBeFile}
                options.Format string = ""
            end
            
            % Delegate to bct.manifold.read function
            if options.Format ~= ""
                obj = bct.manifold.read(fileName, 'Format', options.Format);
            else
                obj = bct.manifold.read(fileName);
            end
        end
    end
end
