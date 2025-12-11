classdef OmegaScrubber < BaseScrubber
    % OmegaScrubber - Scrubber configured for frequency domain
    %
    % OmegaScrubber is a thin wrapper around BaseScrubber that configures
    % the axis for frequency-domain operations. It sets:
    %   - Axis range from Omega domain object
    %   - Label: "Frequency"
    %   - Units: Hertz (Hz)
    %   - Tick formatting with Hz units
    %   - Frequency bin snapping (optional)
    %
    % Usage:
    %   % From Omega domain object
    %   omegaScrubber = OmegaScrubber(omegaObj);
    %
    %   % Manual configuration
    %   omegaScrubber = OmegaScrubber();
    %   omegaScrubber.configureFromOmega(0, 250, 0.5); % fmin, fmax, df
    %
    % See also: BaseScrubber, TimeScrubber, LambdaScrubber
    
    methods
        function obj = OmegaScrubber(omegaObj)
            % Construct OmegaScrubber from Omega domain object
            %
            % Input:
            %   omegaObj - (optional) bct.Omega object
            
            obj@BaseScrubber();
            
            if nargin > 0 && ~isempty(omegaObj)
                obj.configureFromOmega(omegaObj);
            end
        end
        
        function configureFromOmega(obj, omegaObj, varargin)
            % Configure scrubber from Omega domain object or parameters
            %
            % Usage:
            %   configureFromOmega(omegaObj)         % From bct.Omega object
            %   configureFromOmega(fmin, fmax, df)   % From parameters
            
            if isobject(omegaObj) && isa(omegaObj, 'bct.Omega')
                % Extract parameters from Omega object
                fmin = min(omegaObj.f);
                fmax = max(omegaObj.f);
                df = omegaObj.f(2) - omegaObj.f(1); % frequency resolution
            else
                % Manual specification
                if nargin < 3
                    error('OmegaScrubber:InvalidArgs', ...
                          'Usage: configureFromOmega(fmin, fmax, df)');
                end
                fmin = omegaObj;
                fmax = varargin{1};
                df = varargin{2};
            end
            
            % Create tick formatter (Hz units)
            tickFormatter = @(f) sprintf('%.1f Hz', f);
            
            % Create snap function (snap to frequency bins)
            snapFunction = @(f) round(f / df) * df;
            
            % Configure axis
            obj.setAxis(fmin, fmax, 'Frequency', 'omega', ...
                       tickFormatter, snapFunction);
        end
    end
end
