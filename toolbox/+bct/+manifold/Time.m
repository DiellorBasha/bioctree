classdef Time
    %TIME Time dimension properties for spatiotemporal signals
    %
    %   The Time class encapsulates basic properties of the temporal dimension
    %   for spatiotemporal graph signals, including the number of time points
    %   and the sampling frequency.
    %
    %   Properties:
    %       T  - Number of time points (samples)
    %       fs - Sampling frequency (Hz)
    %
    %   Example:
    %       % Create a Time object for 1000 samples at 250 Hz
    %       time = bct.manifold.Time(1000, 250);
    %       
    %       % Access properties
    %       fprintf('Duration: %.2f seconds\n', time.T / time.fs);
    %
    %   See also: bct.manifold.Manifold
    
    properties (SetAccess = public, GetAccess = public)
        T   % Number of time points
        fs  % Sampling frequency (Hz)
    end
    
    properties (SetAccess = private)
        % Temporal resolution manager
        Resolution bct.resolution.temporal = bct.resolution.temporal.empty()  % Temporal resolution object
    end
    
    properties (Dependent)
        dt  % Sampling interval (s)
        t   % Time vector (s)
        SamplingFrequency  % Alias for fs
    end
    
    methods
        function obj = Time(T, fs)
            %TIME Construct a Time object
            %
            %   obj = Time(T, fs) creates a Time object with T time points
            %   and sampling frequency fs.
            %
            %   Inputs:
            %       T  - Number of time points (positive integer)
            %       fs - Sampling frequency in Hz (positive scalar)
            %
            %   Example:
            %       time = bct.manifold.Time(1000, 250);
            
            if nargin > 0
                % Validate T
                if ~isscalar(T) || T < 1 || T ~= round(T)
                    error('Time:InvalidT', 'T must be a positive integer');
                end
                obj.T = T;
                
                % Validate fs
                if ~isscalar(fs) || fs <= 0
                    error('Time:InvalidFs', 'fs must be a positive scalar');
                end
                obj.fs = fs;
                
                % Create temporal resolution object
                obj.Resolution = bct.resolution.temporal(obj);
            end
        end
        
        %% Dependent property getters
        function val = get.dt(obj)
            %GET.DT Sampling interval in seconds
            val = 1 / obj.fs;
        end
        
        function val = get.t(obj)
            %GET.T Time vector in seconds
            val = (0:obj.T-1)' / obj.fs;
        end
        
        function val = get.SamplingFrequency(obj)
            %GET.SAMPLINGFREQUENCY Alias for fs
            val = obj.fs;
        end
        
        function duration = get_duration(obj)
            %GET_DURATION Compute duration in seconds
            %
            %   duration = obj.get_duration() returns the total duration
            %   in seconds based on T and fs.
            %
            %   Returns:
            %       duration - Total duration in seconds (T/fs)
            
            duration = obj.T / obj.fs;
        end
        
        function t = get_time_vector(obj)
            %GET_TIME_VECTOR Generate time vector in seconds
            %
            %   t = obj.get_time_vector() returns a time vector from 0 to
            %   (T-1)/fs with T points.
            %
            %   Returns:
            %       t - [T×1] time vector in seconds
            
            t = (0:obj.T-1)' / obj.fs;
        end
        
        function nyquist = get_nyquist_freq(obj)
            %GET_NYQUIST_FREQ Get Nyquist frequency
            %
            %   nyquist = obj.get_nyquist_freq() returns the Nyquist
            %   frequency (fs/2).
            %
            %   Returns:
            %       nyquist - Nyquist frequency in Hz
            
            nyquist = obj.fs / 2;
        end
        
        function f = get_frequency_axis(obj)
            %GET_FREQUENCY_AXIS Generate full DFT frequency axis
            %
            %   f = obj.get_frequency_axis() returns the full discrete
            %   Fourier transform frequency axis in Hz, ranging from 0 to
            %   fs*(T-1)/T.
            %
            %   The frequency axis is computed as:
            %       f = (0:T-1)' * (fs/T)
            %
            %   This represents the frequencies corresponding to the FFT
            %   bins for a signal of length T sampled at fs Hz.
            %
            %   Returns:
            %       f - [T×1] frequency vector in Hz
            %
            %   Example:
            %       time = bct.manifold.Time(100, 100);
            %       f = time.get_frequency_axis();
            %       % f ranges from 0 to 99 Hz in 1 Hz steps
            %
            %   See also: get_time_vector, fftshift
            
            f = (0:obj.T-1)' * (obj.fs / obj.T);
        end
        
        function disp(obj)
            %DISP Display Time object information
            
            fprintf('  Time object:\n');
            fprintf('    T:  %d time points\n', obj.T);
            fprintf('    fs: %.2f Hz\n', obj.fs);
            fprintf('    Duration: %.4f seconds\n', obj.get_duration());
            fprintf('    Nyquist: %.2f Hz\n', obj.get_nyquist_freq());
        end
    end
end
