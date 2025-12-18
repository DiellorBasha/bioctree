function v_vtx = faceToVertexVector(TR, v_f)

FA = TR.vertexAttachments;
N  = size(TR.Points,1);

v_vtx = zeros(N,3);

for i = 1:N
    faces = FA{i};
    v_vtx(i,:) = mean(v_f(faces,:),1);
end
end
