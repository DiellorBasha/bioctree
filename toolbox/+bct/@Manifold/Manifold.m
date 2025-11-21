classdef Manifold < bct.Domain
    %MANIFOLD  2D cortical surface manifold (triangular mesh)
    %
    % Holds:
    %   V - vertices
    %   F - faces
    %   L - Laplace–Beltrami operator (optional until computed)
    %   M - mass matrix
    %
    % Axis:
    %   Default = vertex index

    properties
        V       % [Nx3] vertices
        F       % [Mx3] faces
        L       % Laplacian (optional)
        M       % Mass matrix (optional)
    end

    methods
        % ---------------------------------------------------------------
        function obj = Manifold(meshStruct)
            % Call superclass constructor
            obj@bct.Domain("Manifold", "mm");

            % Required geometry
            obj.V = meshStruct.V;
            obj.F = meshStruct.F;

            % Optional fields (depends on your meshStruct)
            if isfield(meshStruct, "Laplacian")
                obj.L = meshStruct.Laplacian;
            end
            if isfield(meshStruct, "MassMatrix")
                obj.M = meshStruct.MassMatrix;
            end

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Vertex;

            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            N = size(obj.V,1);

            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Vertex
                    obj.axis = (1:N).';

                otherwise
                    error("Unsupported coordinate mode for Manifold.");
            end
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

    end
end
