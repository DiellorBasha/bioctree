classdef Space < bct.Domain
    %SPACE  Spatial domain representation for a cortical surface mesh.
    %
    % Fields:
    %   V - Nx3 vertex coordinates
    %   F - Mx3 face indices
    %   L - NxN Laplace–Beltrami operator (cotangent FEM)
    %   M - NxN mass matrix (FEM)
    %
    % Axis:
    %   By default the axis is simply the vertex index (1:N), which is the
    %   most natural coordinate for a discrete mesh domain.

    properties
        V   % Vertices [N x 3]
        F   % Faces [M x 3]
        L   % Laplacian (FEM cotangent matrix)
        M   % Mass matrix
    end

    methods
        % ---- Constructor ----
        function obj = Space(meshStruct)
            % Call superclass constructor
            obj@bct.Domain("Space", "mm");

            % Store mesh components
            obj.V = meshStruct.V;
            obj.F = meshStruct.F;
            obj.L = meshStruct.Laplacian;
            obj.M = meshStruct.MassMatrix;

            % Default modes
            obj.resolutionMode = bct.enum.Resolution.Full;
            obj.displayCoordinateMode = bct.enum.Coordinate.Vertex;

            % Build axis according to current coordinate mode
            obj = obj.buildAxis();
        end

        % ------------------------------------------------------------------
        % Build coordinate axis for the Space domain
        % ------------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            % Builds the coordinate axis for the spatial domain.
            %
            % Possible coordinate modes:
            %   Vertex index       (default)
            %   Geodesic distance  (future)
            %   Cortical surface U/V coords (future)
            %
            % For now, simplest: axis = 1:N

            N = size(obj.V,1);

            switch obj.displayCoordinateMode
                case bct.enum.Coordinate.Vertex   % default: vertex index
                    obj.axis = (1:N)';

                case bct.enum.Coordinate.Geodesic
                    % Placeholder: user can implement true geodesic distance
                    % for now: Euclidean distance from first vertex
                    v0 = obj.V(1,:);
                    obj.axis = vecnorm(obj.V - v0, 2, 2);

                otherwise
                    error("Unsupported coordinate mode for Space domain.");
            end
        end

        % ------------------------------------------------------------------
        % Resolution mode handler
        % ------------------------------------------------------------------
        function obj = updateResolution(obj)
            % For Space domain, resolution typically refers to:
            %   - full mesh (all vertices)
            %   - instrument resolution (coarser mesh or downsampled)
            %
            % For now, we leave full resolution as the default.
            %
            % In future: implement mesh decimation here.

            if obj.resolutionMode == bct.enum.Resolution.Full
                % Nothing to do (full mesh)
                return;
            elseif obj.resolutionMode == bct.enum.Resolution.Instrument
                warning("Instrument-resolution spatial decimation not implemented yet.");
            else
                error("Unknown resolution mode.");
            end
        end

        % ------------------------------------------------------------------
        % Coordinate mode handler
        % ------------------------------------------------------------------
        function obj = updateCoordinateMode(obj)
            % Rebuild axis according to display coordinate mode.
            obj = obj.buildAxis();
        end

    end
end
