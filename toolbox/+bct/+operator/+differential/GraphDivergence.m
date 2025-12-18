classdef GraphDivergence < bct.operator.Operator
    %BCT.OPERATOR.DIFFERENTIAL.GRAPHDIVERGENCE
    %
    %   Vertex-wise divergence of an edge signal using GSPBox.
    %
    %   Input  : Edge gradient values [E×1]
    %   Output : Signal on Manifold domain [N×1]
    %
    %   Note: This operator takes raw edge values (from GraphGradient)
    %         and returns a proper Signal on Manifold.

    properties
        Manifold  % Store manifold reference for divergence computation
    end

    methods
        function obj = GraphDivergence(manifold)
            arguments
                manifold (1,1) bct.Manifold
            end
            
            obj.Name = "GraphDivergence";
            obj.InputDomainClass  = "EdgeValues";  % Raw edge values
            obj.OutputDomainClass = "bct.Manifold";
            obj.Manifold = manifold;
        end

        function out = apply(obj, edgeValues)
            arguments
                obj
                edgeValues (:,1) double  % Edge gradient values
            end

            % Get Graph from stored Manifold
            G = obj.Manifold.Graph;

            % Get GSPBox graph structure
            gspG = G.gspGraph("geometry");

            % Ensure edge-vector representation exists
            if ~isfield(gspG, 'Diff')
                gspG = gsp_adj2vec(gspG);
            end

            % Compute divergence: [N×1] vertex values
            div = gsp_div(gspG, edgeValues);

            % Create output Signal on Manifold
            meta = struct();
            meta.Operator = obj.Name;

            out = bct.Signal(div, obj.Manifold, [], meta);
        end
    end
end
