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
        U           % [N x K] eigenvectors
        K           % number of modes
    end
    
    properties (SetObservable, AbortSet)
        lambda      % [K x 1] eigenvalues - triggers axis update when set
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
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Wavenumber;  % Default for filter design

            obj = obj.buildAxis();
            
            % Add listener for lambda property changes
            addlistener(obj, 'lambda', 'PostSet', @obj.onLambdaChanged);
        end

        % ---------------------------------------------------------------
        function onLambdaChanged(obj, ~, ~)
            % Callback when lambda property is set
            % Automatically updates K and rebuilds axis
            if ~isempty(obj.lambda)
                obj.K = length(obj.lambda);
                obj = obj.buildAxis();
            end
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
                    obj.units = "1/mm^2";  % Eigenvalue units

                case bct.enum.CoordinateMode.Wavenumber
                    obj.axis = sqrt(obj.lambda);
                    obj.units = "1/mm";  % Wavenumber units

                case bct.enum.CoordinateMode.Wavelength
                    obj.axis = 1 ./ sqrt(obj.lambda);
                    obj.units = "mm";  % Wavelength units

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
        
        % ---------------------------------------------------------------
        function obj = initializeTransform(obj)
            % Initialize IMFT transform (Lambda → Manifold)
            % Requires Manifold dual to be set and eigenvectors computed
            % Silently returns if prerequisites not met (expected in standard workflow)
            
            if isempty(obj.dual)
                % Dual not set - transform cannot be created yet
                return;
            end
            
            if isempty(obj.U)
                % Eigenvectors not computed - transform cannot be created yet
                return;
            end
            
            % Create IMFT transform object
            obj.transform = bct.factory.transforms.IMFT(obj);
        end

    end
    
    methods (Static)
        function obj = fromHDF5(filename)
            %FROMHDF5 Load Lambda from HDF5 file (lazy loading)
            %
            % Syntax:
            %   obj = bct.Lambda.fromHDF5(filename)
            %
            % Inputs:
            %   filename - Path to HDF5 file
            %
            % Outputs:
            %   obj - Lambda object with eigenvalues and eigenvectors loaded from HDF5
            
            % Read eigenvalues and eigenvectors from HDF5
            lambda_vals = h5read(filename, '/lambda/values');
            
            % Check if eigenvectors exist
            info = h5info(filename, '/lambda');
            hasU = any(strcmp({info.Datasets.Name}, 'U'));
            
            if hasU
                U = h5read(filename, '/lambda/U');
            else
                U = [];
            end
            
            % Create eigenStruct
            eigenStruct = struct();
            eigenStruct.eigenvalues = lambda_vals;
            eigenStruct.eigenvectors = U;
            
            % Create Lambda object
            obj = bct.Lambda(eigenStruct);
        end
    end
end
