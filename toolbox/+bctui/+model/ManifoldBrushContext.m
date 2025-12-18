classdef ManifoldBrushContext < handle
    % ManifoldBrushContext
    %
    % Shared interaction state for manifold brushing.
    %
    % Responsibilities:
    %   - Hold manifold + seed
    %   - Hold active brush model
    %   - Compute brush field on change
    %   - Emit events for rendering / UI
    %
    % Does NOT:
    %   - Render anything
    %   - Own UI components
    %   - Implement brush logic

    %% =========================
    % Public state
    % =========================

    properties (SetObservable)
        Manifold                    % bct.Manifold
        Seed (1,1) double = 1       % Vertex index
        BrushModel bctui.model.ManifoldBrushModel  % ManifoldBrushModel instance
        KernelModel bctui.model.KernelModel     % Optional: For SpectralBrush and TrajectoryBrush
        Field                       % Nx1 brush signal
    end
    
    properties (Dependent)
        SeedPosition                % 1x3 position vector [x y z] at Seed vertex
    end

    %% =========================
    % Events
    % =========================

    events
        SeedChanged
        BrushChanged
        FieldChanged
        ManifoldChanged
    end

    %% =========================
    % Lifecycle
    % =========================

    methods
        function obj = ManifoldBrushContext(varargin)
            % Optional constructor:
            %   ctx = ManifoldBrushContext(manifold)

            if nargin >= 1
                obj.Manifold = varargin{1};
            end

            % Attach listeners
            addlistener(obj, 'Seed', 'PostSet', ...
                @(~,~)obj.onSeedChanged());

            addlistener(obj, 'BrushModel', 'PostSet', ...
                @(~,~)obj.onBrushModelChanged());

            addlistener(obj, 'Manifold', 'PostSet', ...
                @(~,~)obj.onManifoldChanged());
        end
    end

    %% =========================
    % Internal reactions
    % =========================

    methods (Access = private)

        function onSeedChanged(obj)
            notify(obj,'SeedChanged');
            obj.recompute();
        end

        function onBrushModelChanged(obj)
            % React to BrushModel replacement
            
            % Set up listener for Brush changes within the model
            if ~isempty(obj.BrushModel)
                addlistener(obj.BrushModel, 'Brush', 'PostSet', ...
                    @(~,~)obj.onBrushChanged());
            end
            
            notify(obj,'BrushChanged');
            obj.recompute();
        end

        function onBrushChanged(obj)
            % React to Brush changes within BrushModel
            notify(obj,'BrushChanged');
            obj.recompute();
        end

        function onManifoldChanged(obj)
            notify(obj,'ManifoldChanged');

            % Propagate manifold into brush if needed
            if ~isempty(obj.BrushModel) && ...
               ~isempty(obj.BrushModel.Brush)

                obj.BrushModel.Brush.Manifold = obj.Manifold;
            end

            obj.recompute();
        end
    end

    %% =========================
    % Core computation
    % =========================

    methods
        function recompute(obj)
            % Recompute brush field if possible

            if isempty(obj.BrushModel) || isempty(obj.BrushModel.Brush)
                return;
            end

            if isempty(obj.Manifold)
                return;
            end

            try
                w = obj.BrushModel.evaluate(obj.Seed);
            catch ME
                warning('ManifoldBrushContext:EvaluationFailed', ...
                    '%s', ME.message);
                return;
            end

            obj.Field = w;
            notify(obj,'FieldChanged');
        end
    end
    
    %% =========================
    % Dependent property getters
    % =========================
    
    methods
        function pos = get.SeedPosition(obj)
            % Get 3D position of Seed vertex
            pos = [];
            
            if isempty(obj.Manifold)
                return;
            end
            
            V = obj.Manifold.Vertices;
            
            if obj.Seed < 1 || obj.Seed > size(V, 1)
                return;
            end
            
            pos = V(obj.Seed, :);
        end
    end
end
