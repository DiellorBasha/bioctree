classdef Lambda < bct.Domain
    %LAMBDA  Spectral domain for the Manifold's Laplace–Beltrami operator
    %
    % Holds:
    %   lambda - eigenvalues
    %   U      - eigenvectors
    %
    % Axis:
    %   Default = eigenvalues (lambda)

    properties
        lambda      % [K x 1] eigenvalues
        U           % [N x K] eigenvectors
        K           % number of modes
    end

    methods
        % ---------------------------------------------------------------
        function obj = Lambda(eigenStruct)
            obj@bct.Domain("Lambda", "1/mm^2");

            obj.lambda = eigenStruct.eigenvalues(:);
            obj.U      = eigenStruct.eigenvectors;
            obj.K      = length(obj.lambda);

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Lambda;

            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Lambda
                    obj.axis = obj.lambda;

                case bct.enum.CoordinateMode.Wavenumber
                    obj.axis = sqrt(obj.lambda);

                case bct.enum.CoordinateMode.Wavelength
                    obj.axis = 1 ./ sqrt(obj.lambda);

                otherwise
                    error("Unsupported coordinate mode for Lambda.");
            end
        end

        % ---------------------------------------------------------------
        function obj = updateResolution(obj)
            % Future: spectral truncation
        end

        % ---------------------------------------------------------------
        function obj = updateCoordinateMode(obj)
            obj = obj.buildAxis();
        end

    end
end
