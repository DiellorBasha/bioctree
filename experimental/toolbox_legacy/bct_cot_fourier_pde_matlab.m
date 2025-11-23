V = double(B.mesh.Vertices);    % n×3, closed hemisphere, units: mm
F = double(B.mesh.Faces);       % m×3

V=B.mesh.Vertices;
F=B.mesh.Faces;
% V: 3×N nodes, F: 3×T triangles (1-based)
model = createpde(1);
geometryFromMesh(model, V, F);
specifyCoefficients(model, 'm',0,'d',1,'c',1,'a',0,'f',0);  % Laplace-type
FEM = assembleFEMatrices(model);



x = x(:);                       % n×1 scalar
% You already computed these:
G  = grad(V,F);                 % (3m)×n
gF = reshape(G*x,[],3);         % m×3 face gradients
% Per-vertex tangent vector field (as we derived earlier)
Atri = doublearea(V,F)/2;  S = sparse(F(:), repelem((1:size(F,1))',3), 1, size(V,1), size(F,1));
grad_vert = (S*spdiags(Atri,0,size(F,1),size(F,1)))*gF;   % n×3 weighted sum
w_v = S*Atri;  grad_vert = grad_vert./max(w_v,eps);
Nv = per_vertex_normals(V,F); Nv = Nv./max(1e-12,vecnorm(Nv,2,2));
grad_vert = grad_vert - sum(grad_vert.*Nv,2).*Nv;
grad_vert = grad_vert ./ max(vecnorm(grad_vert,2,2),1e-12);  % unit tangent
mag_grad  = vecnorm(grad_vert,2,2);                          % n×1 (for coloring)
