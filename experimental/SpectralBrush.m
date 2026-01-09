classdef SpectralBrush < ManifoldBrush
    % SpectralBrush
    %
    % Manifold brush defined as:
    %   w = U * g(lambda) * U' * delta
    %
    % Requires:
    %   - Manifold with spectral basis (manifold.dual must exist)
    %   - KernelModel for spectral-domain spreading

    properties (SetAccess = protected)
        Type char = 'Spectral'
    end

    properties (SetObservable)
        KernelModel  bctui.model.KernelModel
        SeedBrush bctui.model.DeltaBrush
    end

    methods
        function obj = SpectralBrush(manifold)
            % Constructor requires Manifold with spectral basis
            obj@ManifoldBrush(manifold);
            
            % Default seed brush = Kronecker delta
            obj.SeedBrush = DeltaBrush(manifold);
        end
    end

    methods (Access = protected)
        function w = evaluateCore(obj, varargin)
            % Evaluate spectral selection
            % Usage: w = evaluateCore(seed) or w = evaluateCore()

            % --------------------------------------------------
            % Guard clauses
            % --------------------------------------------------
            if isempty(obj.Manifold.dual)
                error('SpectralBrush:NoSpectralBasis', ...
                    'Manifold must have spectral basis (dual property)');
            end
            
            if isempty(obj.KernelModel)
                error('SpectralBrush:NoKernelModel', ...
                    'KernelModel must be set');
            end

            Lambda = obj.Manifold.dual;
            U      = Lambda.U;
            lambda = Lambda.lambda;

            % --------------------------------------------------
            % Seed selection (delta)
            % --------------------------------------------------
            delta = obj.SeedBrush.evaluate(varargin{:});

            % --------------------------------------------------
            % Spectral spreading
            % --------------------------------------------------
            g = obj.KernelModel.KernelFunction(lambda);

            coeffs = U' * delta;
            w = U * (g .* coeffs);

            % --------------------------------------------------
            % Normalize
            % --------------------------------------------------
            m = max(abs(w));
            if m > 0
                w = w ./ m;
            end
        end
    end
end
