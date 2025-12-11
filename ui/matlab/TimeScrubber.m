classdef TimeScrubber < BaseScrubber
    % TimeScrubber - Scrubber configured for temporal domain
    %
    % TimeScrubber is a thin wrapper around BaseScrubber that configures
    % the axis for time-domain operations. It sets:
    %   - Axis range from Time domain object
    %   - Label: "Time"
    %   - Units: milliseconds (ms)
    %   - Tick formatting with ms units
    %   - Sample-based snapping (optional)
    %
    % Usage:
    %   % From Time domain object
    %   timeScrubber = TimeScrubber(timeObj);
    %
    %   % Manual configuration
    %   timeScrubber = TimeScrubber();
    %   timeScrubber.configureFromTime(0, 1000, 500); % tmin, tmax, fs
    %
    % See also: BaseScrubber, OmegaScrubber, LambdaScrubber
    
    methods
        function obj = TimeScrubber(timeObj)
            % Construct TimeScrubber from Time domain object
            %
            % Input:
            %   timeObj - (optional) bct.Time object
            
            obj@BaseScrubber();
            
            if nargin > 0 && ~isempty(timeObj)
                obj.configureFromTime(timeObj);
            end
        end
        
        function configureFromTime(obj, timeObj, varargin)
            % Configure scrubber from Time domain object or parameters
            %
            % Usage:
            %   configureFromTime(timeObj)           % From bct.Time object
            %   configureFromTime(tmin, tmax, fs)    % From parameters
            
            if isobject(timeObj) && isa(timeObj, 'bct.Time')
                % Extract parameters from Time object
                tmin = min(timeObj.t);
                tmax = max(timeObj.t);
                fs = timeObj.fs;
            else
                % Manual specification
                if nargin < 3
                    error('TimeScrubber:InvalidArgs', ...
                          'Usage: configureFromTime(tmin, tmax, fs)');
                end
                tmin = timeObj;
                tmax = varargin{1};
                fs = varargin{2};
            end
            
            % Create tick formatter (ms units)
            tickFormatter = @(t) sprintf('%.1f ms', t * 1000);
            
            % Create snap function (snap to sample times)
            dt = 1 / fs;
            snapFunction = @(t) round(t / dt) * dt;
            
            % Configure axis
            obj.setAxis(tmin, tmax, 'Time', 'time', ...
                       tickFormatter, snapFunction);
        end
    end
end
