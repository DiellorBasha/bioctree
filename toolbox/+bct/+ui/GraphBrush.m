classdef GraphBrush < ManifoldBrush
    % GraphBrush
    % Graph-based manifold brush using MATLAB graph algorithms

    properties (SetAccess = protected)
        Type char = 'Graph'
    end

    properties
        SelectionMode char {mustBeMember(SelectionMode, ...
            {'KNeighbors','Distance','Component'})} = 'KNeighbors'

        K (1,1) double = 5
        DistanceThreshold (1,1) double = 10
        UseWeighted (1,1) logical = true
    end

    properties (Access = private)
        CachedGraph
        CachedManifold
    end

    methods
        function obj = GraphBrush()
            obj@ManifoldBrush();
        end
    end

    methods (Access = protected)

        function w = evaluateCore(obj, varargin)
            % Evaluate graph brush at seed vertex
            % Usage: w = evaluateCore(seed) or w = evaluateCore()

            N = obj.Manifold.N;
            w = zeros(N,1);

            if isempty(obj.Manifold)
                return;
            end

            % Use provided seed or return zeros if none
            if nargin > 1 && ~isempty(varargin{1})
                seed = varargin{1};
            else
                return;  % No seed provided
            end

            G = obj.getGraph();

            switch obj.SelectionMode
                case 'KNeighbors'
                    d = distances(G, seed);
                    nodes = find(d <= obj.K);

                case 'Distance'
                    d = distances(G, seed);
                    nodes = find(d <= obj.DistanceThreshold);

                case 'Component'
                    bins = conncomp(G);
                    nodes = find(bins == bins(seed));
            end

            w(nodes) = 1;
        end
    end

    methods (Access = private)

        function G = getGraph(obj)
            if isempty(obj.CachedGraph) || obj.CachedManifold ~= obj.Manifold
                G = bct.io.convert.manifoldToMatlabGraph( ...
                    obj.Manifold, 'Weighted', obj.UseWeighted);

                obj.CachedGraph = G;
                obj.CachedManifold = obj.Manifold;
            else
                G = obj.CachedGraph;
            end
        end
    end
end
