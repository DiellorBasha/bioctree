classdef Time < bct.Domain
    %TIME  Temporal domain (sampled time vector)

    properties
        T      % time vector
        fs     % sampling frequency
    end

    methods
        % ---------------------------------------------------------------
        function obj = Time(timeVector, fs)
            % Call Domain constructor
            obj@bct.Domain();

            obj.name  = "Time";
            obj.units = "s";

            obj.T  = timeVector(:);
            obj.fs = fs;

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Time;

            obj = obj.buildAxis();
            
            % Note: Omega dual is created by BCT class when Time is assigned
            % BCT class setter will:
            %   1. Create Omega domain from this Time domain
            %   2. Link them as duals
            %   3. Initialize transforms for both
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Time
                    obj.axis = obj.T;
                    obj.units = "s";  % Time units

                case bct.enum.CoordinateMode.Index
                    obj.axis = (1:obj.N).';
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
