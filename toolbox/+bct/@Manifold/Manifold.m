classdef Manifold < bct.Domain
    %MANIFOLD  2D cortical surface manifold (triangular mesh)
    %
    % Properties:
    %   Vertices         - [N×3] vertex coordinates
    %   Faces            - [M×3] triangular face connectivity
    %   Laplacian        - Laplace-Beltrami operator
    %   MassMatrix       - Diagonal mass matrix (vertex areas)
    %   CotangentMatrix  - Cotangent stiffness matrix
    %   LaplacianType    - Type of Laplacian ("cotangent" or "cotangent-normalized")
    %
    % Axis:
    %   Default = vertex index

    properties
        Vertices         % [N×3] vertex coordinates
        Faces            % [M×3] face connectivity
        Laplacian        % Laplace-Beltrami operator
        MassMatrix       % Diagonal mass matrix
        CotangentMatrix  % Cotangent stiffness matrix
        LaplacianType    % "cotangent" or "cotangent-normalized"
    end

    methods
        % ---------------------------------------------------------------
        function obj = Manifold(meshStruct, laplacianType)
            % MANIFOLD Constructor for Manifold domain
            %
            % Syntax:
            %   obj = Manifold(meshStruct)
            %   obj = Manifold(meshStruct, laplacianType)
            %
            % Inputs:
            %   meshStruct     - Structure with fields:
            %                    .V or .Vertices - [N×3] vertex coordinates
            %                    .F or .Faces    - [M×3] face connectivity
            %   laplacianType  - (optional) "cotangent" (default) or "cotangent-normalized"
            
            % Call superclass constructor
            obj@bct.Domain("Manifold", "mm");

            % Default Laplacian type
            if nargin < 2 || isempty(laplacianType)
                laplacianType = "cotangent";
            end
            obj.LaplacianType = laplacianType;

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

            % Compute Laplacian, MassMatrix, and CotangentMatrix
            obj = obj.computeLaplacian();

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Vertex;

            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function obj = computeLaplacian(obj)
            % Compute Laplacian, MassMatrix, and CotangentMatrix using laplacian function
            [obj.Laplacian, obj.MassMatrix, obj.CotangentMatrix] = ...
                bct.Manifold.laplacian(obj.Vertices, obj.Faces, obj.LaplacianType);
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            N = size(obj.Vertices, 1);

            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Vertex
                    obj.axis = (1:N).';

                otherwise
                    error("Unsupported coordinate mode for Manifold.");
            end
        end

        % ---------------------------------------------------------------
        function M = M(obj)
            % Alias for MassMatrix (for transform compatibility)
            M = obj.MassMatrix;
        end
        
        % ---------------------------------------------------------------
        function obj = updateResolution(obj)
            % Future: decimation
            if obj.resolutionMode == bct.enum.ResolutionMode.Full
                return;
            elseif obj.resolutionMode == bct.enum.ResolutionMode.Instrument
                warning("Instrument-resolution mesh decimation not implemented.");
            else
                error("Unknown resolution mode in Manifold.");
            end
        end

        % ---------------------------------------------------------------
        function obj = updateCoordinateMode(obj)
            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function N = numVertices(obj)
            % Get number of vertices
            N = size(obj.Vertices, 1);
        end

        % ---------------------------------------------------------------
        function M = numFaces(obj)
            % Get number of faces
            M = size(obj.Faces, 1);
        end

    end

    methods (Static)
        [L, M, K] = laplacian(V, F, laplacianType);
        [U, lam, K, M, D, Ls] = meshFourier(mesh, varargin);
        lambda_max = maxLambda(obj, scope);
    end
end
