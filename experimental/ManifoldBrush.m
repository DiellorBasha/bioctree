classdef (Abstract) ManifoldBrush < handle
    % ManifoldBrush
    % Base class for manifold brush operators
    % Each brush is bound to a specific Manifold

    properties (SetObservable)
        Manifold              % REQUIRED: Bct Manifold object
        Weight (1,1) double = 1.0
    end

    properties (Abstract, SetAccess = protected)
        Type char
    end

    methods
        function obj = ManifoldBrush(manifold)
            % Constructor requires Manifold
            if nargin > 0
                obj.Manifold = manifold;
            end
        end
        
        function w = evaluate(obj, varargin)
            % Evaluate selection with optional seed parameter
            % Usage: w = brush.evaluate(seed)
            %        w = brush.evaluate()  % uses default/stored seed
            
            if isempty(obj.Manifold)
                error('ManifoldBrush:NoManifold', ...
                    'Manifold must be set before evaluation');
            end
            
            w0 = obj.evaluateCore(varargin{:});
            w  = obj.Weight * w0;
        end
    end

    methods (Abstract, Access = protected)
        w = evaluateCore(obj, varargin)
    end
end
