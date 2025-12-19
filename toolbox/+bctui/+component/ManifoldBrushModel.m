classdef ManifoldBrushModel < handle
    % ManifoldBrushModel
    % Model for manifold brush using bct.brush API
    %
    % Properties:
    %   Manifold    - bct.Manifold object
    %   BrushType   - Type of brush ('delta', 'gaussian', 'spectral', etc.)
    %   Params      - Struct with brush parameters
    %   Signal      - Cached brush signal (bct.Signal)

    properties (SetObservable)
        Manifold bct.Manifold
        BrushType string = "delta"  % Brush type from bct.brush registry
        Params struct = struct('source', 1)  % Brush parameters
    end
    
    properties (SetAccess = private)
        Signal bct.Signal  % Cached brush signal
    end

    events
        BrushUpdated
    end

    methods
        function obj = ManifoldBrushModel(manifold)
            % Constructor
            if nargin > 0
                obj.Manifold = manifold;
            end
        end
        
        function w = evaluate(obj)
            % Evaluate manifold brush using bct.brush API
            %
            % Returns:
            %   w - [N×1] brush signal on vertices
            
            if isempty(obj.Manifold)
                error('ManifoldBrushModel:NoManifold', ...
                    'Manifold must be set before evaluation');
            end
            
            % Construct brush type string
            brushFn = sprintf('patch_%s', obj.BrushType);
            
            % Evaluate brush using bct.brush.apply
            w = bct.brush.apply(brushFn, obj.Manifold, obj.Params);
            
            % Cache as Signal
            obj.Signal = bct.Signal(w, obj.Manifold);
            
            % Notify listeners
            notify(obj, 'BrushUpdated');
        end
        
        function setParam(obj, name, value)
            % Set a brush parameter and trigger re-evaluation
            obj.Params.(name) = value;
            notify(obj, 'BrushUpdated');
        end
        
        function value = getParam(obj, name)
            % Get a brush parameter value
            if isfield(obj.Params, name)
                value = obj.Params.(name);
            else
                value = [];
            end
        end
        
        function setBrushType(obj, brushType, defaultParams)
            % Change brush type and set default parameters
            %
            % Inputs:
            %   brushType - String ('delta', 'gaussian', 'spectral', etc.)
            %   defaultParams - Optional struct with default parameters
            
            obj.BrushType = brushType;
            
            if nargin > 2 && ~isempty(defaultParams)
                obj.Params = defaultParams;
            else
                % Set minimal default params
                obj.Params = struct('source', obj.getParam('source'));
                if isempty(obj.Params.source)
                    obj.Params.source = 1;
                end
            end
            
            notify(obj, 'BrushUpdated');
        end
        
        function setSeed(obj, seed)
            % Set source vertex (seed)
            obj.setParam('source', seed);
        end
        
        function seed = getSeed(obj)
            % Get source vertex (seed)
            seed = obj.getParam('source');
        end
    end
end
