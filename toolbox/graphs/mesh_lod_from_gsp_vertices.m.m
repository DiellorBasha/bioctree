function LOD = mesh_lod_from_gsp_vertices(Gmesh, V_targets)
% Build mesh LODs whose face counts match the GSP pyramid node counts.
% Inputs:
%   Gmesh      : surfaceMesh (original, high-res)
%   V_targets  : vector of desired vertex counts (from gsp_graph_multiresolution levels)
% Output:
%   LOD(k).mesh         : surfaceMesh at level k
%   LOD(k).targetFaces  : planned face target
%   LOD(k).NumVertices  : actual vertex count after simplify
%   LOD(k).NumFaces     : actual face count after simplify

V0 = double(Gmesh.Vertices);
F0 = double(Gmesh.Faces);

% --- Euler characteristic of the original mesh
E = unique(sort([F0(:,[1 2]); F0(:,[2 3]); F0(:,[3 1])],2),'rows');
chi = size(V0,1) - size(E,1) + size(F0,1);

LOD = struct([]);
for k = 1:numel(V_targets)
    Vt = max(50, round(V_targets(k)));   % be safe
    % Plan faces: F ≈ 2(V - chi). Clamp to sensible minimum.
    Ft_plan = max(100, round( 2*max(Vt - chi, 1) ));

    % Fresh clone from the original each time (avoid compounding artifacts)
    Mk = surfaceMesh(V0, F0);

    % Simplify to planned faces
    simplify(Mk, SimplificationMethod="quadric-decimation", ...
                TargetNumFaces=Ft_plan, BoundaryWeight=10);

    % Optional single refinement step: if vertex count is off a lot, nudge faces
    Vnow = Mk.NumVertices;
    if abs(Vnow - Vt) > 0.1*Vt   % more than 10% off? nudge once
        scale = Vt / max(Vnow,1);
        Ft_nudge = max(80, round(Mk.NumFaces * scale));    % proportional tweak
        simplify(Mk, SimplificationMethod="quadric-decimation", ...
                    TargetNumFaces=Ft_nudge, BoundaryWeight=10);
    end

    % Gentle Taubin to remove decimation chatter (does not change counts much)
    Mk = smoothSurfaceMesh(Mk, 4, Method="Taubin", ScaleFactor=[-0.51, 0.50]);

    % Recompute normals for good shading
    vn = computeNormals(Mk);

    % Stash
    LOD(k).mesh        = Mk;
    LOD(k).targetFaces = Ft_plan;
    LOD(k).NumVertices = Mk.NumVertices;
    LOD(k).NumFaces    = Mk.NumFaces;
    LOD(k).VertexNormals = vn;
end
end
