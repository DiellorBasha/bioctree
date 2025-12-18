classdef DeltaBrush < ManifoldBrush
    % DeltaBrush
    % Kronecker delta at Seed vertex

    properties (SetAccess = protected)
        Type char = 'Delta'
    end
    
    properties
        Seed (1,1) double = 1  % Default seed vertex
    end

    methods
        function obj = DeltaBrush(manifold)
            % Constructor
            obj@ManifoldBrush(manifold);
        end
    end

    methods (Access = protected)
        function w = evaluateCore(obj, varargin)
            % Evaluate delta at seed vertex
            % Usage: w = evaluateCore(seed) or w = evaluateCore()
            
            w = zeros(obj.Manifold.N, 1);
            
            % Use provided seed or default stored seed
            if nargin > 1 && ~isempty(varargin{1})
                seed = varargin{1};
            else
                seed = obj.Seed;
            end
            
            if ~isempty(seed) && seed > 0 && seed <= obj.Manifold.N
                w(seed) = 1;
            end
        end
    end
end
