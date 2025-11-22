classdef Omega < bct.Domain
    %OMEGA  Temporal spectral domain (angular frequency)

    properties
        freq    % Hz
        omega   % rad/s
        N
    end

    methods
        % ---------------------------------------------------------------
        function obj = Omega(timeDomain)
            obj@bct.Domain();

            obj.name  = "Omega";
            obj.units = "Hz";  % Will be set correctly by updateCoordinateMode

            fs = timeDomain.fs;
            N  = timeDomain.N;

            obj.freq  = (0:N-1)' * (fs / N);
            obj.omega = 2*pi*obj.freq;
            obj.axis  = obj.omega;
            obj.N     = N;

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Frequency;  % Default for filter design

            obj.metadata.fs = fs;
            obj.metadata.N  = N;
            
            % Update axis and units based on coordinate mode
            obj = obj.updateCoordinateMode();

            % -------- Automatically assign dual to timeDomain -----------
            obj.setDual(timeDomain);
        end

        function obj = buildAxis(obj)
            % This domain uses its omega axis by default
        end

        function obj = updateResolution(obj)
            % Nothing yet
        end

        function obj = updateCoordinateMode(obj)
            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Omega
                    obj.axis = obj.omega;
                    obj.units = "rad/s";  % Angular frequency units

                case bct.enum.CoordinateMode.Frequency
                    obj.axis = obj.freq;
                    obj.units = "Hz";  % Frequency units

                otherwise
                    error("Unsupported coordinate mode for Omega domain.");
            end
        end
    end
end
