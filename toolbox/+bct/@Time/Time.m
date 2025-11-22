classdef Time < bct.Domain
    %TIME  Temporal domain (sampled time vector)

    properties
        T      % time vector
        fs     % sampling frequency
        N      % number of samples
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
            obj.N  = length(obj.T);

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Time;

            obj = obj.buildAxis();

            % -------- Automatically create and assign dual (Omega) -------
            omegaDomain = bct.Omega(obj);
            obj.setDual(omegaDomain);
            
            % -------- Initialize transforms (FFT/IFFT) -------
            obj.initializeTransform();
            omegaDomain.initializeTransform();
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Time
                    obj.axis = obj.T;

                case bct.enum.CoordinateMode.Index
                    obj.axis = (1:obj.N).';

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
