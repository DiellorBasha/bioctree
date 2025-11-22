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
            % LAMBDA Constructor for Lambda domain
            %
            % Syntax:
            %   obj = Lambda(eigenStruct)
            %
            % Inputs:
            %   eigenStruct - Structure with fields:
            %                 .eigenvalues  - [K×1] eigenvalues
            %                 .eigenvectors - [N×K] eigenvectors (optional)
            
            obj@bct.Domain("Lambda", "1/mm^2");

            obj.lambda = eigenStruct.eigenvalues(:);
            if isfield(eigenStruct, 'eigenvectors') && ~isempty(eigenStruct.eigenvectors)
                obj.U = eigenStruct.eigenvectors;
            else
                obj.U = [];  % Placeholder, will be populated later
            end
            obj.K      = length(obj.lambda);

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Lambda;

            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function U = eigenvectors(obj)
            % Alias for U (for transform compatibility)
            U = obj.U;
        end
        
        % ---------------------------------------------------------------
        function lambda = eigenvalues(obj)
            % Alias for lambda property (for transform compatibility)
            lambda = obj.lambda;
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
