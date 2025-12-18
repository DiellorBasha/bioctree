classdef GraphGradient < bct.operator.Operator
    %BCT.OPERATOR.DIFFERENTIAL.GRAPHGRADIENT
    %
    %   Edge-wise gradient of a vertex signal using GSPBox.
    %
    %   grad(e) = sqrt(w_e) * (f(i) - f(j))
    %
    %   Input  : Signal on Manifold domain
    %   Output : Edge-wise gradient values [E×1]

    methods
        function obj = GraphGradient()
            obj.Name = "GraphGradient";
            obj.InputDomainClass  = "bct.Manifold";
            obj.OutputDomainClass = "EdgeSignal";  % Not a domain class
        end

        function grad = apply(obj, in)
            arguments
                obj
                in (1,1) bct.Signal
            end

            if ~isa(in.Domain, 'bct.Manifold')
                error("bct:operator:GraphGradient:InvalidDomain", ...
                    "GraphGradient requires a Signal on Manifold domain.");
            end

            % Get Manifold and its Graph
            M = in.Domain;          % bct.Manifold
            G = M.Graph;            % bct.Graph

            % Get GSPBox graph structure
            gspG = G.gspGraph("geometry");

            % Ensure edge-vector representation exists
            if ~isfield(gspG, 'Diff')
                gspG = gsp_adj2vec(gspG);
            end

            % Compute gradient: [E×1] edge values
            grad = gsp_grad(gspG, in.Data);

            % Note: Output is raw gradient values, not a Signal object
            % because edges are not a proper Domain in bct architecture
        end
    end
end
