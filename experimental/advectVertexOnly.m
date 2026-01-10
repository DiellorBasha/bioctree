function w_new = advectVertexOnly(TR, w, v_vtx, dt)

V  = TR.Points;
vid = TR.nearestNeighbor(V - dt * v_vtx);

w_new = w(vid);
end
