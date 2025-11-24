classdef Signal < handle
    %SIGNAL Signal data defined on any BCT domain
    %
    %   The Signal class represents data defined on any BCT domain (Manifold, Time,
    %   Lambda, Omega, or Joint). Signal dimensions must match the domain structure.
    %
    %   Properties:
    %       Data     - Signal values matching domain dimensions
    %       Domain   - Reference to bct.Domain object (Manifold, Time, Lambda, Omega, Joint)
    %       Label    - String label/name for the signal
    %       IsVector - Logical flag indicating if signal is vector-valued (3-component)
    %
    %   Dimension Validation:
    %       - Manifold/Lambda: Data must be [N×1] or [N×3] (scalar or vector)
    %       - Time/Omega: Data must be [T×1]
    %       - Joint: Data must match Joint.N → [M×N] or [M×N×3]
    %
    %   Signal Types by Domain:
    %       Manifold/Lambda:
    %         Scalar:  [N×1]   - One value per vertex/eigenmode
    %         Vector:  [N×3]   - 3D vector per vertex/eigenmode
    %       
    %       Time/Omega:
    %         Scalar:  [T×1]   - Time series or frequency spectrum
    %       
    %       Joint (e.g., Manifold_Time):
    %         Scalar:  [N×T]   - Spatiotemporal field
    %         Vector:  [N×T×3] - Spatiotemporal vector field
    %
    %   Example:
    %       % Create BCT object
    %       B = bct.bct.fromMesh(V, F);
    %       B.Time = bct.Time(linspace(0,1,100)', 100);
    %
    %       % Signal on Manifold domain
    %       s1 = bct.Signal(B.Manifold, rand(B.Manifold.N, 1), 'spatial');
    %
    %       % Signal on Time domain
    %       s2 = bct.Signal(B.Time, rand(B.Time.N, 1), 'timeseries');
    %
    %       % Signal on Joint Manifold_Time domain
    %       sz = B.Joint.size();
    %       s3 = bct.Signal(B.Joint, rand(sz(1), sz(2)), 'spatiotemporal');
    %
    %       % Vector signal on Joint domain
    %       s4 = bct.Signal(B.Joint, rand(sz(1), sz(2), 3), 'vector_field');
    %
    %   See also: bct.Domain, bct.Manifold, bct.Time, bct.Lambda, bct.Omega, bct.Joint
    
    properties
        Data           % Signal values matching domain dimensions
        Domain         % bct.Domain object (Manifold, Time, Lambda, Omega, or Joint)
        Label string = ""  % Signal name/label
    end
    
    properties (Dependent)
        IsVector       % True if signal is vector-valued (3-component)
    end
    
    % Legacy properties for backward compatibility
    properties (Dependent, Hidden)
        Manifold       % Deprecated: use Domain instead
        Time           % Deprecated: use Domain instead
        N              % Deprecated: domain-specific
        T              % Deprecated: domain-specific
        IsStatic       % Deprecated: domain-specific
        IsDynamic      % Deprecated: domain-specific
    end
    
    methods (Static)
        function sig = createDelta(domain_obj, varargin)
            %CREATEDELTA Create Kronecker delta (impulse) signal on domain axis
            %
            %   sig = Signal.createDelta(domain_obj, idx) creates delta at index on single domain
            %   sig = Signal.createDelta(joint_domain, idx1, idx2) creates delta on joint domain axes
            %
            % In signal processing, a filter is fully characterized by its impulse response.
            % The delta signal (Kronecker delta) is 1 at the specified location and 0 elsewhere.
            %
            % Inputs:
            %   domain_obj - bct.Domain object (Manifold, Lambda, Time, Omega, or Joint)
            %
            %   For single domains (Manifold, Lambda, Time, Omega):
            %     idx - Index on domain axis (1 to domain.N)
            %
            %   For Joint domains (e.g., Manifold×Time):
            %     idx1 - Index on first domain axis (1 to domain.A.N)
            %     idx2 - Index on second domain axis (1 to domain.B.N)
            %
            % Outputs:
            %   sig - bct.Signal object with impulse at specified location
            %
            % Examples:
            %   % Spatial impulse at vertex 100
            %   delta_v = bct.Signal.createDelta(B.Manifold, 100);
            %   
            %   % Temporal impulse at time index 25
            %   delta_t = bct.Signal.createDelta(B.Time, 25);
            %   
            %   % Spatiotemporal impulse at vertex 50, time 25
            %   delta_vt = bct.Signal.createDelta(B.Joint, 50, 25);
            %
            % See also: bct.Domain.transform
            
            % Validate domain input
            if ~isa(domain_obj, 'bct.Domain')
                error('Signal:InvalidInput', 'First argument must be a bct.Domain object');
            end
            
            % Create delta signal based on domain type
            if isa(domain_obj, 'bct.Joint')
                % Joint domain: requires two indices (one per component domain)
                if numel(varargin) ~= 2
                    error('Signal:InvalidInput', ...
                        'Joint domain requires two indices: createDelta(joint_domain, idx1, idx2)');
                end
                
                idx1 = varargin{1};
                idx2 = varargin{2};
                
                % Get dimensions from component domains
                N1 = domain_obj.A.N;  % First domain (e.g., Manifold)
                N2 = domain_obj.B.N;  % Second domain (e.g., Time)
                
                % Validate indices
                if ~isscalar(idx1) || idx1 < 1 || idx1 > N1 || mod(idx1, 1) ~= 0
                    error('Signal:InvalidIndex', ...
                        'First index must be integer between 1 and %d', N1);
                end
                if ~isscalar(idx2) || idx2 < 1 || idx2 > N2 || mod(idx2, 1) ~= 0
                    error('Signal:InvalidIndex', ...
                        'Second index must be integer between 1 and %d', N2);
                end
                
                % Create [N1×N2] delta
                data = zeros(N1, N2);
                data(idx1, idx2) = 1;
                
                % Create descriptive label based on domain types
                if isa(domain_obj.A, 'bct.Manifold') && isa(domain_obj.B, 'bct.Time')
                    label = sprintf('Delta(v=%d, t=%d)', idx1, idx2);
                elseif isa(domain_obj.A, 'bct.Lambda') && isa(domain_obj.B, 'bct.Omega')
                    label = sprintf('Delta(k=%d, f=%d)', idx1, idx2);
                else
                    label = sprintf('Delta(%s=%d, %s=%d)', ...
                        class(domain_obj.A), idx1, class(domain_obj.B), idx2);
                end
                
            elseif isa(domain_obj, 'bct.Manifold') || isa(domain_obj, 'bct.Lambda') || ...
                   isa(domain_obj, 'bct.Time') || isa(domain_obj, 'bct.Omega')
                % Single domain: requires one index
                if numel(varargin) ~= 1
                    error('Signal:InvalidInput', ...
                        'Single domain requires one index: createDelta(domain, idx)');
                end
                
                idx = varargin{1};
                N_dim = domain_obj.N;
                
                % Validate index
                if ~isscalar(idx) || idx < 1 || idx > N_dim || mod(idx, 1) ~= 0
                    error('Signal:InvalidIndex', ...
                        'Index must be integer between 1 and %d', N_dim);
                end
                
                % Create [N×1] delta
                data = zeros(N_dim, 1);
                data(idx) = 1;
                
                % Create label based on domain type
                if isa(domain_obj, 'bct.Manifold')
                    label = sprintf('Delta(v=%d)', idx);
                elseif isa(domain_obj, 'bct.Lambda')
                    label = sprintf('Delta(k=%d)', idx);
                elseif isa(domain_obj, 'bct.Time')
                    label = sprintf('Delta(t=%d)', idx);
                else  % Omega
                    label = sprintf('Delta(f=%d)', idx);
                end
            else
                error('Signal:UnsupportedDomain', ...
                    'Unsupported domain type: %s', class(domain_obj));
            end
            
            % Create Signal object
            sig = bct.Signal(domain_obj, data, label);
        end
    end
    
    methods
        function obj = Signal(domain_obj, data, label)
            %SIGNAL Construct a Signal object
            %
            %   obj = Signal(domain, data) creates a Signal on the specified domain
            %   obj = Signal(domain, data, label) also sets a label
            %
            %   Inputs:
            %       domain - bct.Domain object (Manifold, Time, Lambda, Omega, or Joint)
            %       data   - Signal values matching domain dimensions
            %       label  - Optional string label
            %
            %   Data dimension requirements by domain type:
            %       Manifold/Lambda: [N×1] scalar or [N×3] vector
            %       Time/Omega:      [T×1] scalar
            %       Joint:           [M×N] scalar or [M×N×3] vector
            %
            %   Examples:
            %       % Manifold signal
            %       s = bct.Signal(B.Manifold, rand(B.Manifold.N, 1), 'spatial');
            %
            %       % Joint Manifold_Time signal
            %       dims = B.Joint.N;
            %       s = bct.Signal(B.Joint, rand(sz(1), sz(2)), 'spatiotemporal');
            
            if nargin > 0
                % Validate domain
                if ~isa(domain_obj, 'bct.Domain')
                    error('Signal:InvalidDomain', ...
                        'First argument must be a bct.Domain object (Manifold, Time, Lambda, Omega, or Joint)');
                end
                obj.Domain = domain_obj;
                
                % Validate and set data
                obj.validateAndSetData(data);
                
                % Set label if provided
                if nargin >= 3
                    obj.Label = string(label);
                end
            end
        end
        
        function validateAndSetData(obj, data)
            %VALIDATEANDSETDATA Validate data dimensions against domain
            
            if isempty(obj.Domain)
                error('Signal:NoDomain', 'Domain must be set before data');
            end
            
            sz = size(data);
            
            % Validation logic depends on domain type
            if isa(obj.Domain, 'bct.Joint')
                % Joint domain: data must be [M×N] or [M×N×3]
                joint_dims = obj.Domain.N;  % [M, N]
                M = joint_dims(1);
                N = joint_dims(2);
                
                if ismatrix(data)
                    % [M×N] scalar signal on joint domain
                    if sz(1) ~= M || sz(2) ~= N
                        error('Signal:DimensionMismatch', ...
                            'Data dimensions [%d×%d] must match Joint.N [%d×%d]', ...
                            sz(1), sz(2), M, N);
                    end
                elseif ndims(data) == 3
                    % [M×N×3] vector signal on joint domain
                    if sz(1) ~= M || sz(2) ~= N || sz(3) ~= 3
                        error('Signal:DimensionMismatch', ...
                            'Vector data must be [%d×%d×3], got [%d×%d×%d]', ...
                            M, N, sz(1), sz(2), sz(3));
                    end
                else
                    error('Signal:InvalidDimensions', ...
                        'Joint domain signal must be 2D [M×N] or 3D [M×N×3]');
                end
                
            elseif isa(obj.Domain, 'bct.Manifold') || isa(obj.Domain, 'bct.Lambda')
                % Spatial/Spectral domain: data must be [N×1] or [N×3]
                N_dim = obj.Domain.N;
                if N_dim == 0
                    error('Signal:InvalidDomain', 'Domain.N must be > 0');
                end
                
                if ~ismatrix(data)
                    error('Signal:InvalidDimensions', ...
                        'Manifold/Lambda signal must be 2D: [N×1] scalar or [N×3] vector');
                end
                
                if sz(1) ~= N_dim
                    error('Signal:DimensionMismatch', ...
                        'First dimension of data (%d) must match Domain.N (%d)', ...
                        sz(1), N_dim);
                end
                
                if sz(2) ~= 1 && sz(2) ~= 3
                    error('Signal:InvalidDimensions', ...
                        'Manifold/Lambda signal must be [N×1] scalar or [N×3] vector, got [%d×%d]', ...
                        sz(1), sz(2));
                end
                
            elseif isa(obj.Domain, 'bct.Time') || isa(obj.Domain, 'bct.Omega')
                % Temporal/Frequency domain: data must be [T×1]
                T_dim = obj.Domain.N;
                if T_dim == 0
                    error('Signal:InvalidDomain', 'Domain.N must be > 0');
                end
                
                if ~iscolumn(data)
                    error('Signal:InvalidDimensions', ...
                        'Time/Omega signal must be column vector [T×1], got [%d×%d]', ...
                        sz(1), sz(2));
                end
                
                if sz(1) ~= T_dim
                    error('Signal:DimensionMismatch', ...
                        'Data length (%d) must match Domain.N (%d)', ...
                        sz(1), T_dim);
                end
                
            else
                error('Signal:UnsupportedDomain', ...
                    'Unsupported domain type: %s', class(obj.Domain));
            end
            
            % Data is valid, set it
            obj.Data = data;
        end
        
        %% Dependent property getters
        function val = get.IsVector(obj)
            %GET.ISVECTOR Check if signal is vector-valued (3-component)
            sz = size(obj.Data);
            
            if isa(obj.Domain, 'bct.Joint')
                % Joint: [M×N×3] is vector
                val = (ndims(obj.Data) == 3) && (sz(3) == 3);
            elseif isa(obj.Domain, 'bct.Manifold') || isa(obj.Domain, 'bct.Lambda')
                % Spatial/Spectral: [N×3] is vector
                val = ismatrix(obj.Data) && (sz(2) == 3);
            elseif isa(obj.Domain, 'bct.Time') || isa(obj.Domain, 'bct.Omega')
                % Temporal: cannot be vector
                val = false;
            else
                val = false;
            end
        end
        
        function m = get.Manifold(obj)
            %GET.MANIFOLD Backward compatibility: return Manifold domain if applicable
            if isa(obj.Domain, 'bct.Manifold')
                m = obj.Domain;
            elseif isa(obj.Domain, 'bct.Joint') && isa(obj.Domain.A, 'bct.Manifold')
                m = obj.Domain.A;
            else
                m = [];
            end
        end
        
        function t = get.Time(obj)
            %GET.TIME Backward compatibility: return Time domain if applicable
            if isa(obj.Domain, 'bct.Time')
                t = obj.Domain;
            elseif isa(obj.Domain, 'bct.Joint') && isa(obj.Domain.B, 'bct.Time')
                t = obj.Domain.B;
            else
                t = [];
            end
        end
        
        function val = get.N(obj)
            %GET.N Get number of spatial points (deprecated, domain-specific)
            if isa(obj.Domain, 'bct.Manifold') || isa(obj.Domain, 'bct.Lambda')
                val = obj.Domain.N;
            elseif isa(obj.Domain, 'bct.Joint')
                % For Joint, return total elements (M*N)
                sz = obj.Domain.N;
                val = sz(1) * sz(2);
            else
                val = size(obj.Data, 1);
            end
        end
        
        function val = get.T(obj)
            %GET.T Get number of time points (deprecated, domain-specific)
            if isa(obj.Domain, 'bct.Time') || isa(obj.Domain, 'bct.Omega')
                val = obj.Domain.N;
            elseif isa(obj.Domain, 'bct.Joint') && (isa(obj.Domain.B, 'bct.Time') || isa(obj.Domain.B, 'bct.Omega'))
                val = obj.Domain.B.N;
            else
                val = 0;  % No time dimension
            end
        end
        
        function val = get.IsStatic(obj)
            %GET.ISSTATIC Check if signal is static (deprecated)
            % Static if domain has no time component
            if isa(obj.Domain, 'bct.Time') || isa(obj.Domain, 'bct.Omega')
                val = false;
            elseif isa(obj.Domain, 'bct.Joint')
                val = ~(isa(obj.Domain.B, 'bct.Time') || isa(obj.Domain.B, 'bct.Omega'));
            else
                val = true;  % Manifold/Lambda only = static
            end
        end
        
        function val = get.IsDynamic(obj)
            %GET.ISDYNAMIC Check if signal has time dimension (deprecated)
            val = ~obj.IsStatic;
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
                if ~isempty(obj.Time)
                    % Handle both old and new Time classes
                    if isprop(obj.Time, 'N')  % New bct.Time
                        duration = (obj.Time.N - 1) / obj.Time.fs;
                        s = [s sprintf('  Duration = %.4f s at %.2f Hz\n', duration, obj.Time.fs)];
                    else  % Old bct.manifold.Time
                        s = [s sprintf('  Duration = %.4f s at %.2f Hz\n', ...
                            obj.Time.get_duration(), obj.Time.fs)];
                    end
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
        
        function sig_out = applyFilter(obj, filter_obj, domain_src, domain_dst)
            %APPLYFILTER Apply filter and transform signal between domains
            %
            %   sig_out = obj.applyFilter(filter, domain_src, domain_dst)
            %
            % Applies a filter in the transform domain and synthesizes result.
            % This is the modern replacement for the old Synthesize/Generate methods.
            %
            % Workflow:
            %   1. Transform signal from source domain (domain_src)
            %   2. Multiply by filter response (filter.evaluate())
            %   3. Inverse transform to destination domain (domain_dst)
            %
            % Inputs:
            %   filter_obj - bct.filters.Filter object (evaluated on transform domain)
            %   domain_src - Source domain (must have .transform property)
            %   domain_dst - Destination domain (dual of source)
            %
            % Example:
            %   % Create impulse in Manifold
            %   delta = bct.Signal.createDelta(B.Manifold, 50);
            %   
            %   % Create spectral filter (Lambda domain)
            %   filt = designer.spatial('heat_wavenumber', 'tau', 0.1);
            %   
            %   % Apply filter: Manifold → Lambda (filter) → Manifold
            %   filtered = delta.applyFilter(filt, B.Manifold, B.Lambda);
            %
            % See also: createDelta, bct.filters.Filter.evaluate
            
            if ~isa(filter_obj, 'bct.filters.Filter')
                error('Signal:InvalidFilter', ...
                    'filter_obj must be a bct.filters.Filter object');
            end
            
            if isempty(domain_src.transform)
                error('Signal:NoTransform', ...
                    'Source domain %s has no transform initialized', domain_src.name);
            end
            
            % Forward transform: domain_src → its dual
            coeffs = domain_src.transform.forward(obj.Data);
            
            % Evaluate filter on transform domain
            H = filter_obj.evaluate();
            
            % Apply filter (element-wise multiplication)
            if isvector(coeffs) && isvector(H)
                filtered_coeffs = coeffs(:) .* H(:);
            else
                filtered_coeffs = coeffs .* H;
            end
            
            % Inverse transform: dual → domain_dst
            if isempty(domain_dst.transform)
                error('Signal:NoTransform', ...
                    'Destination domain %s has no transform initialized', domain_dst.name);
            end
            
            data_out = domain_dst.transform.inverse(filtered_coeffs);
            
            % Create output signal
            label_out = sprintf('%s_filtered_by_%s', obj.Label, filter_obj.Label);
            sig_out = bct.Signal(obj.Manifold, data_out, label_out, obj.Time);
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
