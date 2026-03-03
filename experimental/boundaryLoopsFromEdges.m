function loops = boundaryLoopsFromEdges(boundaryEdges)
% boundaryEdges: Mx2 undirected edges (vertex indices in the hemi mesh)
% loops: cell array of loops, each loop is ordered vertex cycle [v1 v2 ... vK]

    % Build adjacency (boundary graph)
    nV = max(boundaryEdges(:));
    adj = cell(nV,1);
    for i=1:size(boundaryEdges,1)
        a = boundaryEdges(i,1); b = boundaryEdges(i,2);
        adj{a}(end+1) = b;
        adj{b}(end+1) = a;
    end

    % Walk loops
    visited = containers.Map('KeyType','char','ValueType','logical');
    loops = {};

    for i=1:size(boundaryEdges,1)
        a = boundaryEdges(i,1); b = boundaryEdges(i,2);
        key = edgeKey(a,b);
        if isKey(visited,key), continue; end

        % Start a loop
        loop = a;
        prev = a;
        curr = b;

        visited(edgeKey(prev,curr)) = true;

        while true
            loop(end+1) = curr; %#ok<AGROW>

            nbrs = adj{curr};
            % boundary vertices typically have degree 2; pick next not equal prev
            if numel(nbrs) < 2
                break; % open boundary (shouldn't happen in a proper boundary graph)
            end
            nxt = nbrs(1);
            if nxt == prev, nxt = nbrs(2); end

            prev2 = curr;
            curr2 = nxt;

            % if we closed the loop
            if curr2 == loop(1)
                break;
            end

            visited(edgeKey(prev2,curr2)) = true;

            prev = prev2;
            curr = curr2;

            % safety
            if numel(loop) > size(boundaryEdges,1)+5
                break;
            end
        end

        loops{end+1} = loop; %#ok<AGROW>
    end
end

function k = edgeKey(a,b)
    if a>b, t=a; a=b; b=t; end
    k = sprintf('%d_%d',a,b);
end