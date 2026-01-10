function x1 = advectSurfaceApprox(TR, v_f, x0, dt)

VN = TR.vertexNormal;
V  = TR.Points;

% Nearest vertex for normals
vid = TR.nearestNeighbor(x0);

% Project to surface
x0p = x0 - dot(x0 - V(vid,:), VN(vid,:), 2) .* VN(vid,:);

% Locate faces
[ti, bc] = locateOnSurfaceApprox(TR, x0p);

% Interpolate velocity
v = zeros(size(x0));
valid = ~isnan(ti);
v(valid,:) = v_f(ti(valid),:);

% Euler step
x1 = x0p + dt * v;
end
