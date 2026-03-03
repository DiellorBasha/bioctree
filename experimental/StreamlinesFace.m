%% ============================================================
%  Streamlines on a triangle mesh from a face tangent vector field
%  - piecewise-constant direction per face
%  - integrate by ray/edge intersection in each face
%  - cross to neighbor via halfedge twin
%  - update direction angle using delta_halfedge(hCross)
%
%  Requires: M, topo, geom, alpha_face, delta_halfedge
% ============================================================

% --- Mesh data ---
V  = M.Vertices;                      % nV x 3
F  = double(M.Faces);                 % nF x 3 (1-based)
nF = size(F,1);

topo = M.topology;
geom = M.geometry;

FH    = double(topo.faceHalfedges.value);   % nF x 3, [h12 h23 h31]
twinH = double(topo.twin.value);            % nH x 1
faceH = double(topo.face.value);            % nH x 1  (face index for each halfedge)

% --- Face tangent frames ---
t1 = geom.face.tangent1.value;        % nF x 3
t2 = geom.face.tangent2.value;        % nF x 3

% --- Face centroids (good default seeds) ---
C = geom.face.centroids.value;        % nF x 3

% --- Direction field as face angles (your output of integration) ---
% alpha_face: nF x 1
% delta_halfedge: nH x 1 (transport increment across each halfedge)
%   delta = dTheta - phi   (or whichever convention you chose)
alpha_face = result.alpha_face;       % <-- your integrated face angles
delta = trans.delta_halfedge.value;   % nH x 1

% Wrap helpers
wrap2pi  = @(x) mod(x + pi, 2*pi) - pi;   % (-pi,pi]

%% ============================================================
%  Parameters for integration
% ============================================================
nSeeds     = 200;        % number of streamlines to trace
maxSteps   = 400;        % max triangle crossings per streamline
epsHit     = 1e-10;      % minimum ray parameter s to accept
epsNudge   = 1e-8;       % nudge to enter next face after crossing
stepLimit  = inf;        % optional max arclength (set inf to ignore)

% Seed selection: random faces or specific region
seedFaces = randi(nF, [nSeeds, 1]);   % random faces
% seedFaces = (1:nSeeds).';           % or deterministic

% Store polylines (3D points) in a cell array
streamlines = cell(nSeeds,1);

%% ============================================================
%  Main loop: trace each streamline
% ============================================================
for sIdx = 1:nSeeds

    f = seedFaces(sIdx);                 % current face
    if f < 1 || f > nF, continue; end

    % Start at centroid (you can also randomize barycentric seeds)
    p = C(f,:);                          % current point in R^3

    % Initial angle in this face
    a = alpha_face(f);
    a = wrap2pi(a);

    % Accumulated length
    Lacc = 0;

    % Preallocate polyline points
    P = zeros(maxSteps+1, 3);
    P(1,:) = p;
    pCount = 1;

    % Trace
    for k = 1:maxSteps

        % Current direction in 3D tangent plane of face f
        dir3 = cos(a)*t1(f,:) + sin(a)*t2(f,:);
        dn = norm(dir3);
        if dn < 1e-14
            break;
        end
        dir3 = dir3 / dn;

        % Triangle vertices
        vid = F(f,:);
        v1 = V(vid(1),:);
        v2 = V(vid(2),:);
        v3 = V(vid(3),:);

        % Build local 2D coordinates in face tangent frame:
        % coords of vertices and current point relative to v1
        e21 = v2 - v1;
        e31 = v3 - v1;

        v2_2 = [dot(e21, t1(f,:)), dot(e21, t2(f,:))];
        v3_2 = [dot(e31, t1(f,:)), dot(e31, t2(f,:))];

        p1   = p - v1;
        p_2  = [dot(p1, t1(f,:)), dot(p1, t2(f,:))];

        d_2  = [dot(dir3, t1(f,:)), dot(dir3, t2(f,:))];
        dn2  = norm(d_2);
        if dn2 < 1e-14
            break;
        end
        d_2 = d_2 / dn2;

        % Triangle in 2D:
        % V1=(0,0), V2=v2_2, V3=v3_2
        A2 = [0,0];
        B2 = v2_2;
        C2 = v3_2;

        % Intersect ray p_2 + s*d_2 with each segment
        bestS = inf;
        bestEdgeIdx = 0;
        bestQ2 = [NaN NaN];

        % Edge 1: V1->V2 corresponds to halfedge FH(f,1) (v1->v2)
        segA = A2; segB = B2;
        r = segB - segA;
        M2 = [d_2(:), -r(:)];
        detM = M2(1,1)*M2(2,2) - M2(1,2)*M2(2,1);
        if abs(detM) > 1e-14
            rhs = (segA - p_2);
            sol = (1/detM) * [ M2(2,2), -M2(1,2); -M2(2,1), M2(1,1)] * rhs(:);
            sRay = sol(1); tSeg = sol(2);
            if sRay > epsHit && tSeg >= -1e-12 && tSeg <= 1+1e-12 && sRay < bestS
                bestS = sRay; bestEdgeIdx = 1;
                bestQ2 = p_2 + bestS*d_2;
            end
        end

        % Edge 2: V2->V3 corresponds to halfedge FH(f,2) (v2->v3)
        segA = B2; segB = C2;
        r = segB - segA;
        M2 = [d_2(:), -r(:)];
        detM = M2(1,1)*M2(2,2) - M2(1,2)*M2(2,1);
        if abs(detM) > 1e-14
            rhs = (segA - p_2);
            sol = (1/detM) * [ M2(2,2), -M2(1,2); -M2(2,1), M2(1,1)] * rhs(:);
            sRay = sol(1); tSeg = sol(2);
            if sRay > epsHit && tSeg >= -1e-12 && tSeg <= 1+1e-12 && sRay < bestS
                bestS = sRay; bestEdgeIdx = 2;
                bestQ2 = p_2 + bestS*d_2;
            end
        end

        % Edge 3: V3->V1 corresponds to halfedge FH(f,3) (v3->v1)
        segA = C2; segB = A2;
        r = segB - segA;
        M2 = [d_2(:), -r(:)];
        detM = M2(1,1)*M2(2,2) - M2(1,2)*M2(2,1);
        if abs(detM) > 1e-14
            rhs = (segA - p_2);
            sol = (1/detM) * [ M2(2,2), -M2(1,2); -M2(2,1), M2(1,1)] * rhs(:);
            sRay = sol(1); tSeg = sol(2);
            if sRay > epsHit && tSeg >= -1e-12 && tSeg <= 1+1e-12 && sRay < bestS
                bestS = sRay; bestEdgeIdx = 3;
                bestQ2 = p_2 + bestS*d_2;
            end
        end

        % No valid hit => stop
        if bestEdgeIdx == 0 || ~isfinite(bestS)
            break;
        end

        % Convert intersection point back to 3D
        q = v1 + bestQ2(1)*t1(f,:) + bestQ2(2)*t2(f,:);

        % Update length + record
        segLen = norm(q - p);
        Lacc = Lacc + segLen;
        p = q;
        pCount = pCount + 1;
        P(pCount,:) = p;

        if Lacc > stepLimit
            break;
        end

        % Determine crossed halfedge and neighbor face
        hCross = FH(f, bestEdgeIdx);
        ht = twinH(hCross);

        if ht <= 0
            break; % boundary (shouldn't happen on sphere)
        end

        fNext = faceH(ht);
        if fNext <= 0 || fNext > nF
            break;
        end

        % --- Transport/update angle across this halfedge ---
        % This is the key "JS-style" integration: angle evolves by delta(h).
        a = a + delta(hCross);
        a = wrap2pi(a);

        % Move to next face
        f = fNext;

        % Nudge slightly along the new direction to avoid sticking on the edge
        dir3_next = cos(a)*t1(f,:) + sin(a)*t2(f,:);
        dn = norm(dir3_next);
        if dn < 1e-14
            break;
        end
        dir3_next = dir3_next / dn;
        p = p + epsNudge * dir3_next;

        % record nudged point (optional; usually keep it)
        pCount = pCount + 1;
        if pCount > size(P,1)
            break;
        end
        P(pCount,:) = p;

    end

    % Trim and store
    streamlines{sIdx} = P(1:pCount,:);
end

%% ============================================================
%  Output for visualization
% ============================================================
% For three.js, you typically want an array of polylines.
% Each streamline is an N x 3 polyline in R^3.
%
% Example: pack into a struct for JSON export
out = struct();
out.streamlines = streamlines;

fprintf('Traced %d streamlines.\n', nSeeds);
