classdef Graph < bct.Domain
    %GRAPH  General graph domain for discrete signals on nodes.
    %
    % Fields:
    %   A   - adjacency matrix (NxN sparse)
    %   D   - degree matrix (NxN sparse)
    %   L   - graph Laplacian (combinatorial or normalized)
    %   coords - optional spatial coordinates for visualization
    %
    % Axis:
    %   Default = node index (1:N)
    %
    %   This class parallels bct.Manifold but uses graph structure
    %   instead of a triangulated surface mesh.

    properties
        A           % adjacency matrix [N x N]
        D           % degree matrix    [N x N]
        L           % graph Laplacian  [N x N]
        coords      % optional node coordinates [N x dim]
        N           % number of nodes
        LaplacianType string {mustBeMember(LaplacianType, ["combinatorial","normalized"])} = "combinatorial"
    end

    methods
        % ---------------------------------------------------------------
        function obj = Graph(adjStruct)
            % adjStruct must contain:
            %   A           adjacency matrix (sparse)
            %   coords      (optional)

            obj@bct.Domain("Graph", "node");

            % Required
            obj.A = sparse(adjStruct.A);
            obj.N = size(obj.A,1);

            % Optional coordinates
            if isfield(adjStruct, "coords")
                obj.coords = adjStruct.coords;
            else
                obj.coords = [];
            end

            % Degree matrix
            obj.D = spdiags(sum(obj.A,2), 0, obj.N, obj.N);

            % Default Laplacian
            obj.L = obj.computeLaplacian();

            % Domain modes
            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Vertex;

            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function L = computeLaplacian(obj)
            % Compute combinatorial or normalized graph Laplacian

            switch obj.LaplacianType
                case "combinatorial"
                    L = obj.D - obj.A;

                case "normalized"
                    % avoid division by zero
                    d = full(diag(obj.D));
                    dInvSqrt = 1 ./ sqrt(max(d, eps));
                    Dinv = spdiags(dInvSqrt, 0, obj.N, obj.N);
                    L = speye(obj.N) - Dinv * obj.A * Dinv;
            end

            obj.L = L;
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            % Default axis = node index
            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Vertex
                    obj.axis = (1:obj.N).';

                otherwise
                    error("Unsupported coordinate mode for Graph domain.");
            end
        end

        % ---------------------------------------------------------------
        function obj = updateResolution(obj)
            % Future: graph coarsening, Graclus, spectral coarsening…
            if obj.resolutionMode == bct.enum.ResolutionMode.Full
                return;

            elseif obj.resolutionMode == bct.enum.ResolutionMode.Instrument
                warning("Graph coarsening not implemented yet.");

            else
                error("Unknown resolution mode for Graph domain.");
            end
        end

        % ---------------------------------------------------------------
        function obj = updateCoordinateMode(obj)
            obj = obj.buildAxis();
        end

    end
end
