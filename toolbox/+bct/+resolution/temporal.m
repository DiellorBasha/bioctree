classdef temporal < handle
    %TEMPORAL Temporal resolution manager for time-varying signals
    %
    %   Manages temporal resolution information including:
    %   - Sampling-limited resolution (from sampling frequency)
    %   - Current temporal band selection
    %   - Time window definitions
    %   - Frequency selectors
    %
    %   Properties:
    %     Units          - Temporal units (bct.resolution.Units)
    %     Time           - Associated Time object
    %
    %   Sampling-Limited Resolution:
    %     f_nyquist      - Nyquist frequency [Hz]
    %     T_min          - Minimum period [units]
    %     omega_max      - Maximum angular frequency [rad/s]
    %
    %   Current Temporal Band:
    %     f_band         - [f_low, f_high] frequency range [Hz]
    %     T_band         - [T_min, T_max] period range [units]
    %     omega_band     - [omega_low, omega_high] angular freq range
    %
    %   Time Window:
    %     t_window       - [t_start, t_end] time window [units]
    %     n_samples      - Number of samples in window
    %
    %   Example:
    %     time = bct.manifold.Time(1000, 0.001);  % 1000 samples, 1ms dt
    %     res = bct.resolution.temporal(time);
    %     res.Units = bct.resolution.Units.ms;
    %     res.setBand([8, 12], bct.resolution.Quantity.frequency);  % Alpha band
    %     res.setWindow([100, 900]);  % Analyze 100-900 ms
    %
    %   See also: bct.resolution.spatial, bct.manifold.Time
    
    properties
        Units bct.resolution.Units = bct.resolution.Units.s  % Temporal units
        Time bct.manifold.Time                               % Associated Time object
    end
    
    properties (SetAccess = private)
        % Current temporal band
        f_band double = []      % [f_low, f_high] Hz
        T_band double = []      % [T_min, T_max] units
        omega_band double = []  % [omega_low, omega_high] rad/s
        
        % Time window
        t_window double = []    % [t_start, t_end] units
        n_samples double = []   % Number of samples in window
    end
    
    properties (Dependent)
        % Sampling-limited resolution
        f_nyquist    % Nyquist frequency [Hz]
        T_min        % Minimum resolvable period [units]
        omega_max    % Maximum angular frequency [rad/s]
        
        % Sampling properties
        fs           % Sampling frequency [Hz]
        dt           % Sampling interval [units]
        T_total      % Total duration [units]
        
        % Resolution as struct
        resolution   % struct with period, f_nyquist, omega_max
    end
    
    methods
        function obj = temporal(time)
            %TEMPORAL Construct temporal resolution manager
            %
            %   res = bct.resolution.temporal(time) creates a temporal
            %   resolution manager for the given Time object
            %
            %   Inputs:
            %     time - bct.manifold.Time object
            
            if nargin < 1 || isempty(time)
                error('bct:resolution:temporal:NoTime', ...
                    'Time object required');
            end
            
            obj.Time = time;
        end
        
        %% Dependent properties
        function val = get.fs(obj)
            %GET.FS Sampling frequency [Hz]
            if ~isempty(obj.Time) && ~isempty(obj.Time.SamplingFrequency)
                val = obj.Time.SamplingFrequency;
            elseif ~isempty(obj.Time) && ~isempty(obj.Time.dt)
                val = 1 / obj.Time.dt;
            else
                val = [];
            end
        end
        
        function val = get.dt(obj)
            %GET.DT Sampling interval [units]
            if ~isempty(obj.Time) && ~isempty(obj.Time.dt)
                val = obj.Time.dt;
            elseif ~isempty(obj.fs)
                val = 1 / obj.fs;
            else
                val = [];
            end
        end
        
        function val = get.T_total(obj)
            %GET.T_TOTAL Total duration [units]
            if ~isempty(obj.Time) && ~isempty(obj.Time.T)
                val = obj.Time.T;
            else
                val = [];
            end
        end
        
        function val = get.f_nyquist(obj)
            %GET.F_NYQUIST Nyquist frequency [Hz]
            if ~isempty(obj.fs)
                val = obj.fs / 2;
            else
                val = [];
            end
        end
        
        function val = get.T_min(obj)
            %GET.T_MIN Minimum resolvable period [units]
            if ~isempty(obj.f_nyquist)
                val = 1 / obj.f_nyquist;
            else
                val = [];
            end
        end
        
        function val = get.omega_max(obj)
            %GET.OMEGA_MAX Maximum angular frequency [rad/s]
            if ~isempty(obj.f_nyquist)
                val = 2 * pi * obj.f_nyquist;
            else
                val = [];
            end
        end
        
        function R = get.resolution(obj)
            %GET.RESOLUTION Get resolution struct
            if isempty(obj.f_nyquist)
                R = struct('period', '', 'f_nyquist', [], 'omega_max', [], 'dt', []);
                return;
            end
            
            period_str = sprintf('%.4f %s', obj.T_min, obj.Units.toString());
            
            R = struct(...
                'period', period_str, ...
                'f_nyquist', obj.f_nyquist, ...
                'omega_max', obj.omega_max, ...
                'dt', obj.dt ...
            );
        end
        
        %% Band selection methods
        function setBand(obj, range, quantity)
            %SETBAND Set current temporal band
            %
            %   res.setBand([low, high], quantity) sets the temporal band
            %   using the specified quantity type
            %
            %   Inputs:
            %     range    - [low, high] range values
            %     quantity - bct.resolution.Quantity enum
            %
            %   Example:
            %     res.setBand([8, 12], bct.resolution.Quantity.frequency);  % Alpha
            %     res.setBand([0.08, 0.125], bct.resolution.Quantity.period);
            
            if nargin < 3
                quantity = bct.resolution.Quantity.frequency;
            end
            
            % Convert to frequency range [Hz]
            switch quantity
                case bct.resolution.Quantity.frequency
                    obj.f_band = range;
                    
                case bct.resolution.Quantity.period
                    % T = 1/f → f = 1/T
                    obj.f_band = [1/range(2), 1/range(1)];
                    
                case bct.resolution.Quantity.omega
                    % ω = 2πf → f = ω/(2π)
                    obj.f_band = [range(1)/(2*pi), range(2)/(2*pi)];
            end
            
            % Compute other band representations
            if ~isempty(obj.f_band)
                obj.T_band = [1/obj.f_band(2), 1/obj.f_band(1)];
                obj.omega_band = [2*pi*obj.f_band(1), 2*pi*obj.f_band(2)];
            end
        end
        
        function setWindow(obj, window, units)
            %SETWINDOW Set time window for analysis
            %
            %   res.setWindow([t_start, t_end]) sets the time window
            %
            %   res.setWindow([t_start, t_end], units) specifies units
            %   ('samples', 'time', 'ms', 's')
            %
            %   Inputs:
            %     window - [start, end] values
            %     units  - 'samples', 'time', or time unit string
            %
            %   Example:
            %     res.setWindow([100, 900], 'ms');
            %     res.setWindow([50, 500], 'samples');
            
            if nargin < 3
                units = 'time';  % Assume same units as Time object
            end
            
            units = string(units);
            
            if units == "samples"
                % Window specified in sample indices
                obj.n_samples = diff(window) + 1;
                if ~isempty(obj.dt)
                    obj.t_window = window * obj.dt;
                end
            else
                % Window specified in time units
                obj.t_window = window;
                if ~isempty(obj.dt)
                    obj.n_samples = round(diff(window) / obj.dt) + 1;
                end
            end
        end
        
        function indices = getTimeIndices(obj)
            %GETTIMEINDICES Get sample indices for current time window
            %
            %   indices = res.getTimeIndices() returns the sample indices
            %   that fall within the current time window
            %
            %   Returns:
            %     indices - Column vector of sample indices
            
            if isempty(obj.t_window)
                error('bct:resolution:temporal:NoWindow', ...
                    'No time window set. Use setWindow() first.');
            end
            
            if isempty(obj.Time.t)
                error('bct:resolution:temporal:NoTimeVector', ...
                    'No time vector available in Time object.');
            end
            
            t = obj.Time.t;
            mask = (t >= obj.t_window(1)) & (t <= obj.t_window(2));
            indices = find(mask);
        end
        
        function freq_indices = getFrequencyIndices(obj, freq_vector)
            %GETFREQUENCYINDICES Get frequency indices in current band
            %
            %   indices = res.getFrequencyIndices(freq_vector) returns
            %   the indices of frequencies that fall within the current
            %   temporal band
            %
            %   Inputs:
            %     freq_vector - Frequency vector [Hz]
            %
            %   Returns:
            %     indices - Column vector of frequency indices
            
            if isempty(obj.f_band)
                error('bct:resolution:temporal:NoBand', ...
                    'No temporal band set. Use setBand() first.');
            end
            
            mask = (freq_vector >= obj.f_band(1)) & (freq_vector <= obj.f_band(2));
            freq_indices = find(mask);
        end
        
        %% Conversion methods
        function val = convert(~, value, fromQuantity, toQuantity)
            %CONVERT Convert between temporal quantity representations
            %
            %   val = res.convert(value, fromQuantity, toQuantity)
            %
            %   Example:
            %     T = res.convert(10, Quantity.frequency, Quantity.period);
            
            % Convert from → frequency
            switch fromQuantity
                case bct.resolution.Quantity.frequency
                    f = value;
                case bct.resolution.Quantity.period
                    f = 1 / value;
                case bct.resolution.Quantity.omega
                    f = value / (2*pi);
            end
            
            % Convert frequency → to
            switch toQuantity
                case bct.resolution.Quantity.frequency
                    val = f;
                case bct.resolution.Quantity.period
                    val = 1 / f;
                case bct.resolution.Quantity.omega
                    val = 2*pi * f;
            end
        end
        
        %% Display methods
        function disp(obj)
            %DISP Display temporal resolution information
            fprintf('\n  <a href="matlab:helpPopup bct.resolution.temporal">temporal</a> resolution:\n\n');
            fprintf('    Units: %s\n', obj.Units.toString());
            
            if ~isempty(obj.fs)
                fprintf('\n  Sampling Properties:\n');
                fprintf('    fs (sampling freq): %.2f Hz\n', obj.fs);
                fprintf('    dt (interval):      %.4f %s\n', obj.dt, obj.Units.toString());
                if ~isempty(obj.T_total)
                    fprintf('    T_total (duration): %.2f %s\n', obj.T_total, obj.Units.toString());
                end
            end
            
            if ~isempty(obj.f_nyquist)
                fprintf('\n  Sampling-Limited Resolution:\n');
                fprintf('    f_nyquist:  %.2f Hz\n', obj.f_nyquist);
                fprintf('    T_min:      %.4f %s\n', obj.T_min, obj.Units.toString());
                fprintf('    omega_max:  %.2f rad/s\n', obj.omega_max);
            end
            
            if ~isempty(obj.f_band)
                fprintf('\n  Current Temporal Band:\n');
                fprintf('    f:     [%.2f, %.2f] Hz\n', obj.f_band(1), obj.f_band(2));
                fprintf('    T:     [%.4f, %.4f] %s\n', obj.T_band(1), obj.T_band(2), obj.Units.toString());
                fprintf('    omega: [%.2f, %.2f] rad/s\n', obj.omega_band(1), obj.omega_band(2));
            end
            
            if ~isempty(obj.t_window)
                fprintf('\n  Time Window:\n');
                fprintf('    t: [%.2f, %.2f] %s\n', obj.t_window(1), obj.t_window(2), obj.Units.toString());
                if ~isempty(obj.n_samples)
                    fprintf('    n_samples: %d\n', obj.n_samples);
                end
            end
            fprintf('\n');
        end
    end
end
