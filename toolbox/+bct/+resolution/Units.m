classdef Units < uint8
    %UNITS Enumeration for spatial and temporal units
    %
    %   Spatial units:
    %     Units.mm    - Millimeters
    %     Units.cm    - Centimeters
    %     Units.m     - Meters
    %
    %   Temporal units:
    %     Units.ms    - Milliseconds
    %     Units.s     - Seconds
    %     Units.Hz    - Hertz (frequency)
    %
    %   See also: bct.resolution.spatial, bct.resolution.temporal
    
    enumeration
        % Spatial units
        mm  (1)  % Millimeters
        cm  (2)  % Centimeters
        m   (3)  % Meters
        
        % Temporal units
        ms  (4)  % Milliseconds
        s   (5)  % Seconds
        Hz  (6)  % Hertz
    end
    
    methods
        function str = toString(obj)
            %TOSTRING Convert unit to string representation
            str = char(obj);
        end
        
        function scale = toSI(obj)
            %TOSI Get conversion factor to SI units (m or s)
            switch obj
                case bct.resolution.Units.mm
                    scale = 1e-3;  % mm to m
                case bct.resolution.Units.cm
                    scale = 1e-2;  % cm to m
                case bct.resolution.Units.m
                    scale = 1;     % m to m
                case bct.resolution.Units.ms
                    scale = 1e-3;  % ms to s
                case bct.resolution.Units.s
                    scale = 1;     % s to s
                case bct.resolution.Units.Hz
                    scale = 1;     % Hz to Hz
            end
        end
    end
end
