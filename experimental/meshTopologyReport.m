function info = meshTopologyReport(F)
    E = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
    E = sort(E,2);

    [Eu,~,ic] = unique(E,'rows');
    counts = accumarray(ic,1);

    info.Eu = Eu;
    info.counts = counts;

    info.boundaryEdges = Eu(counts==1,:);
    info.nonmanifoldEdges = Eu(counts>2,:);
    info.isClosed = isempty(info.boundaryEdges) && isempty(info.nonmanifoldEdges);
end