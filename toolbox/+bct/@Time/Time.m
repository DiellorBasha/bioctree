classdef Time < bct.Domain
    %TIME  Temporal domain (sampled time vector)

    properties
        fs     % sampling frequency
    end

    methods
        % ---------------------------------------------------------------
        function obj = Time(timeVectorOrN, fs)
            % TIME Constructor for temporal domain
            %
            % Syntax:
            %   obj = bct.Time(timeVector, fs)
            %   obj = bct.Time(N, fs)
            %
            % Inputs:
            %   timeVectorOrN - Either:
            %                   - Time vector [N×1] (e.g., linspace(0,1,100)')
            %                   - Scalar N (number of time points)
            %   fs            - Sampling frequency in Hz
            %
            % Outputs:
            %   obj - Time domain object with N time points
            
            % Call Domain constructor
            obj@bct.Domain();

            obj.name  = "Time";
            obj.units = "s";
            obj.fs = fs;

            % Handle both time vector and scalar N inputs
            if isscalar(timeVectorOrN)
                % Create time vector from N and fs
                N = timeVectorOrN;
                dt = 1/fs;  % Time step
                obj.axis = (0:dt:(N-1)*dt).';
            else
                % Use provided time vector
                obj.axis = timeVectorOrN(:);
            end

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Time;
            
            % Note: Omega dual is created by BCT class when Time is assigned
            % BCT class setter will:
            %   1. Create Omega domain from this Time domain
            %   2. Link them as duals
            %   3. Initialize transforms for both
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            % buildAxis is called during coordinate mode changes
            % For Time, axis is already set in constructor
            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Time
                    % axis already contains time vector, just ensure units
                    obj.units = "s";  % Time units

                case bct.enum.CoordinateMode.Index
                    % Rebuild as indices
                    N = length(obj.axis);
                    obj.axis = (1:N).';
                    obj.units = "samples";  % Index units

                otherwise
                    error("Unsupported coordinate mode for Time domain.");
            end
        end

        % ---------------------------------------------------------------
        function obj = updateResolution(obj)
            % Only full resolution is implemented for now
        end

        % ---------------------------------------------------------------
        function obj = updateCoordinateMode(obj)
            obj = obj.buildAxis();
        end
    end
end
