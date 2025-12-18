function out = graph(in, k)
%BCT.OPERATOR.MODULATE.GRAPH
%   Point (frequency-index) modulation of a graph signal
%
%   Equivalent to GSPBox gsp_modulate:
%       fm(x) = sqrt(N) * f(x) .* u_k(x)
%
%   Inputs:
%     in  - bct.Signal on Graph (vertex-based)
%     k   - eigenmode index (0-based, as in GSPBox)
%
%   Output:
%     out - bct.Signal on Graph (vertex-based)

    arguments
        in (1,1) bct.Signal
        k (1,1) double {mustBeInteger, mustBeNonnegative}
    end

    if in.DomainType ~= "Graph"
        error("bct:operator:modulate:graph:InvalidDomain", ...
            "Input Signal must live on a Graph domain.");
    end

    % Retrieve graph
    G = in.Domain;
    gspG = G.GSP;

    % Apply GSPBox modulation
    data = gsp_modulate(gspG, in.Data, k);

    % Output Signal
    out = bct.Signal( ...
        data, ...
        G, ...
        bct.enum.DomainLocation.Vertex, ...
        struct( ...
            'Operator', 'graph_modulate', ...
            'ModeIndex', k, ...
            'ParentSignal', in.Id ) );
end
