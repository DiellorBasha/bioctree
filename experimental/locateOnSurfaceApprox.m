function [ti, bc] = locateOnSurfaceApprox(TR, x)

V  = TR.Points;
FA = TR.vertexAttachments;

vid = TR.nearestNeighbor(x);

ti = nan(size(x,1),1);
bc = nan(size(x,1),3);

for i = 1:size(x,1)
    for f = FA{vid(i)}
        b = cartesianToBarycentric(TR, f, x(i,:));
        if all(b >= -1e-6)
            ti(i) = f;
            bc(i,:) = b;
            break
        end
    end
end
end
