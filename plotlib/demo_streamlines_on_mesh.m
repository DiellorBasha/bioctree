function demo_streamlines_on_mesh(V,F,grad_face, nSeeds, step_mm, nSteps)
    % V: n×3, F: m×3 (double), grad_face: m×3 (tangent vectors, per face)
    if nargin<4, nSeeds = 200; end
    if nargin<5, step_mm = 2.0; end
    if nargin<6, nSteps = 120; end

    % Unit tangent field per face
    gf = grad_face;
    mag = sqrt(sum(gf.^2,2))+eps;
    gf = gf ./ mag;

    % Face centroids for seeds
    C = (V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:))/3;

    % Face–face adjacency via edges
    F2F = face_adjacency(F);  % m×3, neighbor across opposite edge; 0 if boundary

    % Seed faces (random)
    m = size(F,1);
    seed_faces = randi(m,[nSeeds,1]);

    figure; hold on
    tsurf(F,V,'FaceAlpha',0.15,'EdgeAlpha',0.05);
    axis image off
    title('Streamlines of \nabla x (tangent field)'); drawnow

    for s = 1:nSeeds
        f = seed_faces(s);
        p = C(f,:);  % start at centroid of face f
        for t = 1:nSteps
            v1 = gf(f,:);                         % field in current face
            % RK2: half step
            p_mid = project_to_face_plane(p + 0.5*step_mm*v1, V, F(f,:));
            v2 = v1;  % (field is constant per face; keep v1)
            p_next = p + step_mm*v2;

            % If next point leaves face, hop across the crossed edge
            [f2, p2] = step_across_face(p, p_next, V, F, f, F2F);
            if f2 == 0, break; end  % reached boundary (shouldn't happen on closed hemi)
            plot3([p(1) p2(1)], [p(2) p2(2)], [p(3) p2(3)], '-k');
            p = p2; f = f2;
        end
    end
end

function F2F = face_adjacency(F)
    % Returns m×3 neighbors across edges opposite (v1,v2,v3)
    m = size(F,1);
    F2F = zeros(m,3);
    E = [F(:,[2 3]) (1:m) 1+0*F(:,1);   % edge opposite vertex 1 is (v2,v3)
         F(:,[3 1]) (1:m) 2+0*F(:,1);   % opposite 2 is (v3,v1)
         F(:,[1 2]) (1:m) 3+0*F(:,1)];  % opposite 3 is (v1,v2)
    E(:,1:2) = sort(E(:,1:2),2);
    [~,I,J] = unique(E(:,1:2),'rows');
    % pair up duplicates
    counts = accumarray(J,1);
    pairs  = find(counts==2);
    for k = 1:numel(pairs)
        idx = find(J==pairs(k));
        e1 = E(idx(1),:); e2 = E(idx(2),:);
        F2F(e1(3), e1(4)) = e2(3);
        F2F(e2(3), e2(4)) = e1(3);
    end
end

function pproj = project_to_face_plane(p, V, tri)
    % orthoproject point p to plane of triangle tri
    e1 = V(tri(2),:)-V(tri(1),:);
    e2 = V(tri(3),:)-V(tri(1),:);
    n  = cross(e1,e2); n = n/(norm(n)+eps);
    v  = p - V(tri(1),:);
    pproj = p - dot(v,n)*n;
end

function [f_next, p_next] = step_across_face(p, p_try, V, F, f, F2F)
    % Move from p in face f toward p_try; if leaving, cross to neighbor
    tri = F(f,:);
    % barycentric of p_try; if inside (all >=0), stay
    bc = barycentric_coords(p_try, V(tri,:));
    if all(bc >= -1e-9)
        f_next = f; p_next = p_try; return;
    end
    % leaving across edge where bc is minimal
    [~, whichNeg] = min(bc);
    f_next = F2F(f, whichNeg);
    if f_next == 0
        p_next = p; return
    end
    % clamp to boundary edge intersection as new point
    bc_clamped = max(bc,0); bc_clamped = bc_clamped/sum(bc_clamped);
    p_on_edge = bc_clamped(1)*V(tri(1),:) + bc_clamped(2)*V(tri(2),:) + bc_clamped(3)*V(tri(3),:);
    p_next = p_on_edge;
end

function bc = barycentric_coords(p, triV)
    % triV: 3×3 (rows v1,v2,v3)
    v0 = triV(2,:)-triV(1,:); v1 = triV(3,:)-triV(1,:); v2 = p-triV(1,:);
    d00=dot(v0,v0); d01=dot(v0,v1); d11=dot(v1,v1); d20=dot(v2,v0); d21=dot(v2,v1);
    denom = d00*d11 - d01*d01 + eps;
    v = (d11*d20 - d01*d21)/denom;
    w = (d00*d21 - d01*d20)/denom;
    u = 1 - v - w;
    bc = [u v w];
end
