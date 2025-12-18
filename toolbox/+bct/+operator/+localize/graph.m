function out = graph(G, kernelFn, nodes)
%BCT.OPERATOR.LOCALIZE.GRAPH
%   Localize a spectral kernel on a graph at given node(s)
%
%   Equivalent to gsp_localize, but returns a bct.Signal

    arguments
        G (1,1) bct.Graph
        kernelFn (1,1) function_handle
        nodes (:,1) double {mustBeInteger}
    end

    % Create delta signals
    N = G.N;
    f = zeros(N, numel(nodes));
    for k = 1:numel(nodes)
        f(nodes(k), k) = 1;
    end

    % Spectral filtering (GSPBox)
    gspG = G.GSP;
    coeff = gsp_gft(gspG, f);
    gvals = kernelFn(gspG.e);
    coeff = coeff .* gvals;
    data = gsp_igft(gspG, coeff);

    out = bct.Signal( ...
        data, ...
        G, ...
        bct.enum.DomainLocation.Vertex, ...
        struct( ...
            'Operator', 'graph_localize', ...
            'SeedNodes', nodes ) );
end
