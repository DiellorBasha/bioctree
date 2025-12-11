classdef BaseScrubber < Component
    % BaseScrubber - Interactive 1D axis navigation with kernel visualization
    %
    % BaseScrubber provides a universal scrubber UI component for selecting
    % regions on 1D axes. Features include:
    %   - Draggable center knob for positioning
    %   - Scroll to adjust width
    %   - Click-to-set center
    %   - Multiple kernel shapes (gaussian, rectangular, triangular, etc.)
    %   - Symmetric and asymmetric modes
    %   - Domain-specific configuration via setAxis()
    %
    % Usage:
    %   scrubber = BaseScrubber();
    %   scrubber.setAxis(axisMin, axisMax, label, domain, tickFmt, snapFn);
    %   scrubber.setCenter(value);
    %   scrubber.setWidth(value);
    %   scrubber.setKernelShape('gaussian');
    %
    % Events:
    %   onChange - Fired when user adjusts center/width
    %              Event data contains: center, width, domain, kernelShape
    %
    % See also: TimeScrubber, OmegaScrubber, LambdaScrubber, ManifoldScrubber
    
    properties
        % Callbacks
        OnChange function_handle = @(src, evt) []; % User callback for changes
    end
    
    properties (Access = private)
        AxisMin double = 0
        AxisMax double = 100
        AxisLabel char = 'Axis'
        DomainType char = 'generic'
        TickFormatter function_handle = @(x) num2str(x, '%.2f')
        SnapFunction function_handle = @(x) x
        
        Center double = 50
        Width double = 20
        KernelShape char = 'gaussian'
        IsSymmetric logical = true
    end
    
    methods
        function obj = BaseScrubber()
            % Construct BaseScrubber component
            obj@Component();
            obj.loadFromTemplate('scrubber');
            obj.initialize();
        end
        
        function setAxis(obj, axisMin, axisMax, label, domain, tickFormatter, snapFunction)
            % Configure axis parameters
            %
            % Inputs:
            %   axisMin - Minimum axis value
            %   axisMax - Maximum axis value
            %   label - Axis label string
            %   domain - Domain type ('time', 'omega', 'lambda', 'manifold')
            %   tickFormatter - Function handle for formatting tick labels
            %   snapFunction - Function handle for snapping values
            
            obj.AxisMin = axisMin;
            obj.AxisMax = axisMax;
            obj.AxisLabel = label;
            obj.DomainType = domain;
            
            if nargin >= 6 && ~isempty(tickFormatter)
                obj.TickFormatter = tickFormatter;
            end
            
            if nargin >= 7 && ~isempty(snapFunction)
                obj.SnapFunction = snapFunction;
            end
            
            % Send axis configuration to JavaScript
            axisSpec = struct(...
                'min', axisMin, ...
                'max', axisMax, ...
                'label', label, ...
                'domain', domain, ...
                'tickFormatter', obj.createJSFormatter(tickFormatter), ...
                'snap', obj.createJSSnap(snapFunction) ...
            );
            
            obj.sendMessage('setAxis', axisSpec);
            
            % Reset center and width to reasonable defaults
            obj.Center = (axisMin + axisMax) / 2;
            obj.Width = (axisMax - axisMin) * 0.2;
        end
        
        function setCenter(obj, value)
            % Set the center position
            %
            % Input:
            %   value - Center value (will be clamped to axis range)
            
            obj.Center = max(obj.AxisMin, min(obj.AxisMax, value));
            obj.sendMessage('setCenter', obj.Center);
        end
        
        function setWidth(obj, value)
            % Set the window width
            %
            % Input:
            %   value - Width value (positive)
            
            obj.Width = abs(value);
            obj.sendMessage('setWidth', obj.Width);
        end
        
        function setKernelShape(obj, shape)
            % Set the kernel shape
            %
            % Input:
            %   shape - One of: 'gaussian', 'rectangular', 'triangular',
            %           'hamming', 'hann', 'tukey'
            
            validShapes = {'gaussian', 'rectangular', 'triangular', ...
                          'hamming', 'hann', 'tukey'};
            
            if ~ismember(shape, validShapes)
                error('BaseScrubber:InvalidShape', ...
                      'Invalid kernel shape. Must be one of: %s', ...
                      strjoin(validShapes, ', '));
            end
            
            obj.KernelShape = shape;
            obj.sendMessage('setKernelShape', shape);
        end
        
        function enableAsymmetricMode(obj, enable)
            % Enable or disable asymmetric mode
            %
            % Input:
            %   enable - true/false
            
            obj.IsSymmetric = ~enable;
            obj.sendMessage('enableAsymmetricMode', enable);
        end
        
        function reset(obj)
            % Reset to default center/width
            
            obj.Center = (obj.AxisMin + obj.AxisMax) / 2;
            obj.Width = (obj.AxisMax - obj.AxisMin) * 0.2;
            obj.KernelShape = 'gaussian';
            obj.IsSymmetric = true;
            
            obj.sendMessage('reset', []);
        end
        
        function [center, width] = getWindow(obj)
            % Get current window parameters
            %
            % Outputs:
            %   center - Center position
            %   width - Window width
            
            center = obj.Center;
            width = obj.Width;
        end
        
        function spec = toWindowSpec(obj)
            % Convert to WindowSpec structure
            %
            % Output:
            %   spec - Structure with fields: center, width, domain, kernel
            
            spec = struct(...
                'center', obj.Center, ...
                'width', obj.Width, ...
                'domain', obj.DomainType, ...
                'kernel', obj.KernelShape, ...
                'isSymmetric', obj.IsSymmetric ...
            );
        end
        
        function fromWindowSpec(obj, spec)
            % Load from WindowSpec structure
            %
            % Input:
            %   spec - Structure with fields: center, width, kernel
            
            if isfield(spec, 'center')
                obj.setCenter(spec.center);
            end
            
            if isfield(spec, 'width')
                obj.setWidth(spec.width);
            end
            
            if isfield(spec, 'kernel')
                obj.setKernelShape(spec.kernel);
            end
            
            if isfield(spec, 'isSymmetric')
                obj.enableAsymmetricMode(~spec.isSymmetric);
            end
        end
    end
    
    methods (Access = protected)
        function initialize(obj)
            % Initialize component after HTML is loaded
            
            % Set default axis
            obj.setAxis(obj.AxisMin, obj.AxisMax, obj.AxisLabel, ...
                       obj.DomainType, obj.TickFormatter, obj.SnapFunction);
        end
        
        function onMessage(obj, data)
            % Handle messages from JavaScript
            
            if ~isfield(data, 'type')
                return;
            end
            
            switch data.type
                case 'onChange'
                    % Update internal state
                    if isfield(data, 'center')
                        obj.Center = data.center;
                    end
                    if isfield(data, 'width')
                        obj.Width = data.width;
                    end
                    if isfield(data, 'kernelShape')
                        obj.KernelShape = data.kernelShape;
                    end
                    
                    % Fire user callback
                    if ~isempty(obj.OnChange)
                        eventData = struct(...
                            'center', obj.Center, ...
                            'width', obj.Width, ...
                            'domain', obj.DomainType, ...
                            'kernelShape', obj.KernelShape ...
                        );
                        obj.OnChange(obj, eventData);
                    end
                    
                otherwise
                    warning('BaseScrubber:UnknownMessage', ...
                           'Unknown message type: %s', data.type);
            end
        end
        
        function jsFormatter = createJSFormatter(~, matlabFormatter)
            % Convert MATLAB formatter to JavaScript-compatible string
            % This is a simplified approach - in production, you might
            % want to use function serialization
            
            % For now, just use default formatting in JS
            % The tick formatter is already handled by JS
            jsFormatter = '(x) => x.toFixed(2)';
        end
        
        function jsSnap = createJSSnap(~, matlabSnap)
            % Convert MATLAB snap function to JavaScript-compatible string
            
            % For now, no snapping in JS - MATLAB will handle it
            jsSnap = '(x) => x';
        end
        
        function sendMessage(obj, cmd, value)
            % Send command to JavaScript
            
            msg = struct('cmd', cmd, 'value', value);
            obj.Data = msg;
        end
    end
end
