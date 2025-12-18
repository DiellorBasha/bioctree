function [face, bc, pos] = stepFaceWalk(TR, v_f, face, bc, dt)

F = TR.ConnectivityList;
V = TR.Points;

% Current triangle vertices
verts = V(F(face,:),:);

% Convert barycentric → Cartesian
pos = bc(1)*verts(1,:) + bc(2)*verts(2,:) + bc(3)*verts(3,:);

% Velocity in this face
v = v_f(face,:);

% Euler step in tangent plane
pos_new = pos + dt * v;

% New barycentric coords (same face initially)
bc_new = cartesianToBarycentric(TR, face, pos_new);

% Check if still inside
if all(bc_new >= 0)
    bc = bc_new;
    pos = pos_new;
    return
end

% Otherwise, find crossed edge
[~, idx] = min(bc_new);   % most negative barycentric coord
nbr = TR.neighbors(face, idx);

if isnan(nbr)
    % boundary hit: clamp
    bc = max(bc_new,0);
    bc = bc / sum(bc);
    pos = bc(1)*verts(1,:) + bc(2)*verts(2,:) + bc(3)*verts(3,:);
    return
end

% Move to neighboring face
face = nbr;
bc = cartesianToBarycentric(TR, face, pos_new);
pos = pos_new;
end
