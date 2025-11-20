classdef Signal < handle
    %SIGNAL Signal data defined on a Manifold
    %
    %   The Signal class represents data defined on a spatial manifold (mesh or graph)
    %   with optional temporal evolution. Signals can be scalar-valued or vector-valued
    %   (3-component) at each spatial location.
    %
    %   Properties:
    %       Data     - Signal values ([N×1], [N×T], [N×3], or [N×T×3])
    %       Manifold - Reference to bct.manifold.Manifold object
    %       Time     - Reference to bct.manifold.Time object (optional)
    %       Label    - String label/name for the signal
    %       IsVector - Logical flag indicating if signal is vector-valued (3-component)
    %
    %   Dimensions:
    %       N - Number of spatial points (must match Manifold.N)
    %       T - Number of time points (must match Time.T if Time exists)
    %
    %   Signal Types:
    %       Scalar static:    [N×1]   - One value per vertex
    %       Scalar dynamic:   [N×T]   - Time-varying scalar at each vertex
    %       Vector static:    [N×3]   - 3D vector at each vertex
    %       Vector dynamic:   [N×T×3] - Time-varying 3D vector at each vertex
    %
    %   Example:
    %       % Create manifold and time
    %       M = bct.manifold.Manifold(V, F);
    %       T = bct.manifold.Time(1000, 250);
    %
    %       % Scalar static signal
    %       s1 = bct.signal.Signal(M, rand(M.N, 1), 'random_activation');
    %
    %       % Scalar dynamic signal
    %       s2 = bct.signal.Signal(M, rand(M.N, T.T), 'timeseries', T);
    %
    %       % Vector static signal (e.g., tangent vectors)
    %       s3 = bct.signal.Signal(M, rand(M.N, 3), 'gradient_field');
    %
    %   See also: bct.manifold.Manifold, bct.manifold.Time
    
    properties
        Data           % Signal values: [N×1], [N×T], [N×3], or [N×T×3]
        Manifold       % bct.manifold.Manifold object
        Time           % bct.manifold.Time object (optional, can also be in Manifold.Time)
        Label string = ""  % Signal name/label
    end
    
    properties (Dependent)
        IsVector       % True if signal is vector-valued (3-component)
        N              % Number of spatial points
        T              % Number of time points (0 if static)
        IsStatic       % True if signal has no time dimension
        IsDynamic      % True if signal has time dimension
    end
    
    methods
        function obj = Signal(manifold, data, label, time_obj)
            %SIGNAL Construct a Signal object
            %
            %   obj = Signal(manifold, data) creates a Signal with given data
            %   obj = Signal(manifold, data, label) also sets a label
            %   obj = Signal(manifold, data, label, time_obj) also sets Time object
            %
            %   Inputs:
            %       manifold - bct.manifold.Manifold object
            %       data     - Signal values ([N×1], [N×T], [N×3], or [N×T×3])
            %       label    - Optional string label
            %       time_obj - Optional bct.manifold.Time object
            %
            %   The data dimensions are validated against the manifold dimensions.
            
            if nargin > 0
                % Validate manifold
                if ~isa(manifold, 'bct.manifold.Manifold')
                    error('Signal:InvalidManifold', ...
                        'First argument must be a bct.manifold.Manifold object');
                end
                obj.Manifold = manifold;
                
                % Set Time object if provided
                if nargin >= 4 && ~isempty(time_obj)
                    obj.Time = time_obj;
                end
                
                % Validate and set data
                obj.validateAndSetData(data);
                
                % Set label if provided
                if nargin >= 3
                    obj.Label = string(label);
                end
            end
        end
        
        function validateAndSetData(obj, data)
            %VALIDATEANDSETDATA Validate data dimensions against manifold
            
            if isempty(obj.Manifold)
                error('Signal:NoManifold', 'Manifold must be set before data');
            end
            
            N = obj.Manifold.N;
            if N == 0
                error('Signal:InvalidManifold', 'Manifold.N must be > 0');
            end
            
            % Get expected time dimension from obj.Time
            if ~isempty(obj.Time)
                has_time = true;
                T_expected = obj.Time.T;
            else
                has_time = false;
                T_expected = 0;
            end
            
            % Validate data dimensions
            sz = size(data);
            
            % Must start with N
            if sz(1) ~= N
                error('Signal:DimensionMismatch', ...
                    'First dimension of data (%d) must match Manifold.N (%d)', ...
                    sz(1), N);
            end
            
            % Check for valid signal types
            if ismatrix(data)
                % [N×1] scalar static, [N×T] scalar dynamic, or [N×3] vector static
                if sz(2) == 1
                    % [N×1] scalar static - always valid
                elseif sz(2) == 3
                    % [N×3] could be vector static or scalar with T=3
                    % Assume vector static unless Manifold.Time.T == 3
                    if has_time && T_expected == 3
                        % Ambiguous case - could be either, accept as scalar dynamic
                        warning('Signal:AmbiguousDimensions', ...
                            'Data is [N×3] and Manifold.Time.T=3. Interpreting as scalar dynamic. Use [N×3×1] for vector static.');
                    end
                elseif has_time && sz(2) == T_expected
                    % [N×T] scalar dynamic - valid
                elseif ~has_time && sz(2) > 1
                    error('Signal:DimensionMismatch', ...
                        'Data is [%d×%d] but Manifold has no Time. Expected [N×1] or [N×3]', ...
                        sz(1), sz(2));
                else
                    error('Signal:DimensionMismatch', ...
                        'Data is [%d×%d]. Expected [N×1], [N×T=%d], or [N×3]', ...
                        sz(1), sz(2), T_expected);
                end
            elseif ndims(data) == 3
                % [N×T×3] vector dynamic
                if sz(3) ~= 3
                    error('Signal:InvalidVectorDimension', ...
                        '3D data must have size [N×T×3], got [%d×%d×%d]', ...
                        sz(1), sz(2), sz(3));
                end
                if ~has_time
                    error('Signal:NoTimeForDynamic', ...
                        'Data is [N×T×3] but Manifold has no Time property');
                end
                if sz(2) ~= T_expected
                    error('Signal:DimensionMismatch', ...
                        'Second dimension (%d) must match Manifold.Time.T (%d)', ...
                        sz(2), T_expected);
                end
            else
                error('Signal:InvalidDimensions', ...
                    'Data must be 2D or 3D, got %dD', ndims(data));
            end
            
            obj.Data = data;
        end
        
        %% Dependent property getters
        function val = get.IsVector(obj)
            %GET.ISVECTOR Check if signal is vector-valued
            sz = size(obj.Data);
            if ismatrix(obj.Data)
                % [N×3] is vector static (unless Time.T == 3, handled above)
                val = (sz(2) == 3) && (isempty(obj.Manifold.Time) || ...
                       obj.Manifold.Time.T ~= 3);
            else
                % [N×T×3] is vector dynamic
                val = (ndims(obj.Data) == 3) && (sz(3) == 3);
            end
        end
        
        function val = get.N(obj)
            %GET.N Get number of spatial points
            val = size(obj.Data, 1);
        end
        
        function val = get.T(obj)
            %GET.T Get number of time points (0 if static)
            sz = size(obj.Data);
            if obj.IsVector
                if ndims(obj.Data) == 3
                    val = sz(2);  % [N×T×3]
                else
                    val = 0;      % [N×3] static
                end
            else
                if sz(2) > 1 && sz(2) ~= 3
                    val = sz(2);  % [N×T] scalar dynamic
                else
                    val = 0;      % [N×1] static
                end
            end
        end
        
        function val = get.IsStatic(obj)
            %GET.ISSTATIC Check if signal is static (no time dimension)
            val = (obj.T == 0);
        end
        
        function val = get.IsDynamic(obj)
            %GET.ISDYNAMIC Check if signal has time dimension
            val = (obj.T > 0);
        end
        
        %% Utility methods
        function s = summary(obj)
            %SUMMARY Get text summary of signal properties
            s = sprintf('Signal: "%s"\n', obj.Label);
            s = [s sprintf('  Type: %s %s\n', ...
                ternary(obj.IsVector, 'Vector', 'Scalar'), ...
                ternary(obj.IsStatic, 'static', 'dynamic'))];
            s = [s sprintf('  Dimensions: [%s]\n', ...
                num2str(size(obj.Data)))];
            s = [s sprintf('  N = %d spatial points\n', obj.N)];
            if obj.IsDynamic
                s = [s sprintf('  T = %d time points\n', obj.T)];
                if ~isempty(obj.Manifold.Time)
                    s = [s sprintf('  Duration = %.4f s at %.2f Hz\n', ...
                        obj.Manifold.Time.get_duration(), obj.Manifold.Time.fs)];
                end
            end
        end
        
        function disp(obj)
            %DISP Display signal information
            fprintf('%s', obj.summary());
        end
        
        function x = get_spatial_snapshot(obj, t)
            %GET_SPATIAL_SNAPSHOT Extract spatial data at time index t
            %
            %   x = obj.get_spatial_snapshot(t) returns spatial signal at time t
            %
            %   For static signals, returns the data (ignores t)
            %   For dynamic signals, returns data(:,t) or data(:,t,:)
            
            if obj.IsStatic
                x = obj.Data;
            else
                if nargin < 2 || isempty(t)
                    error('Signal:TimeIndexRequired', ...
                        'Time index required for dynamic signals');
                end
                if t < 1 || t > obj.T
                    error('Signal:InvalidTimeIndex', ...
                        'Time index must be between 1 and %d', obj.T);
                end
                
                if obj.IsVector
                    x = squeeze(obj.Data(:, t, :));  % [N×3]
                else
                    x = obj.Data(:, t);  % [N×1]
                end
            end
        end
        
        function ts = get_temporal_trace(obj, node_idx)
            %GET_TEMPORAL_TRACE Extract time series at spatial node(s)
            %
            %   ts = obj.get_temporal_trace(node_idx) returns time series
            %   at specified node index/indices
            %
            %   Returns [T×1] for scalar or [T×3] for vector signals
            
            if obj.IsStatic
                error('Signal:NoTimeDimension', ...
                    'Signal is static (no temporal dimension)');
            end
            
            if nargin < 2 || isempty(node_idx)
                error('Signal:NodeIndexRequired', 'Node index required');
            end
            
            if any(node_idx < 1) || any(node_idx > obj.N)
                error('Signal:InvalidNodeIndex', ...
                    'Node index must be between 1 and %d', obj.N);
            end
            
            if obj.IsVector
                ts = squeeze(obj.Data(node_idx, :, :));  % [T×3] or [length(node_idx)×T×3]
            else
                ts = obj.Data(node_idx, :)';  % [T×1] or [T×length(node_idx)]
            end
        end
    end
end

function result = ternary(condition, true_val, false_val)
    %TERNARY Ternary operator helper
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
