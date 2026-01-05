Design Document: Cached Surface Frames in bct.Manifold
1. Objective

Provide a single API entry point that computes and caches orthonormal frames on a bct.Manifold:

Face frame: 
(
𝑁
𝑓
,
𝑇
1
𝑓
,
𝑇
2
𝑓
)
(N
f
	​

,T1
f
	​

,T2
f
	​

) per face

Vertex frame: 
(
𝑁
𝑣
,
𝑇
1
𝑣
,
𝑇
2
𝑣
)
(N
v
	​

,T1
v
	​

,T2
v
	​

) per vertex

Computed once and stored in M.Geometry, so repeated calls are O(1) retrieval.

2. Definitions
Frame

For each support element (face or vertex), define a right-handed orthonormal triple:

𝑁
N : unit normal vector in 
𝑅
3
R
3

𝑇
1
T1 : unit tangent vector orthogonal to 
𝑁
N

𝑇
2
T2 : unit tangent vector orthogonal to both 
𝑁
N and 
𝑇
1
T1

with:

𝑇
2
=
𝑁
×
𝑇
1
T2=N×T1
Caching location

M.Geometry is the cache container

Stored frames must be invalidated when vertices or faces change.

3. Public API
3.1 Single public function

Implement:

out = bct.manifold.frame(M)


Behavior:

If frames are not cached or cache is stale → compute and store them.

Return a struct out containing both vertex and face frames.

Return structure:

out = struct( ...
  'Face',   struct('N',Nf, 'T1',T1f, 'T2',T2f), ...
  'Vertex', struct('N',Nv, 'T1',T1v, 'T2',T2v) );

3.2 Optional convenience accessors (recommended but not required)

If you want smaller calls later:

bct.manifold.normals(M) returns out.Face.N + out.Vertex.N

bct.manifold.tangents(M) returns T1,T2 pairs from cached frames

These should not recompute; they should call bct.manifold.frame(M) and extract.

4. Cache schema in M.Geometry

Store in M.Geometry.Frame:

M.Geometry.Frame = struct( ...
  'Face',   struct('N',Nf, 'T1',T1f, 'T2',T2f), ...
  'Vertex', struct('N',Nv, 'T1',T1v, 'T2',T2v), ...
  'Meta',   struct('Hash',hash, 'CreatedOn',datetime("now")) );

4.1 Cache validity key (“hash”)

Minimum requirement: invalidate when geometry changes. Use a lightweight meta key:

Nv = size(V,1)

Nf = size(F,1)

bbox = [min(V); max(V)] (2×3)

checksum = [Nv Nf bbox(:)']

Store checksum as Meta.Hash. On each call, recompute and compare. If mismatch → recompute.

Rationale: simple, deterministic, cheap. Not cryptographically robust; sufficient for typical in-session mutation tracking.

5. Computation specification
5.1 Input geometry

V = M.Vertices [Nv×3]

F = M.Faces [Nf×3], 1-indexed

5.2 Normals using surfaceMesh

Create once per computation:

mesh = surfaceMesh(V, F);
computeNormals(mesh, "faces");
computeNormals(mesh, "vertices");

Nf = mesh.FaceNormals;     % [Nf×3], unit
Nv = mesh.VertexNormals;   % [Nv×3], unit

5.3 Face tangents

Use your existing approach:

T1f = V(F(:,2),:) - V(F(:,1),:);              % [Nf×3]
T1f = T1f - sum(T1f .* Nf, 2) .* Nf;           % project to face tangent plane (safe)
T1f = normalizeRows(T1f);

T2f = cross(Nf, T1f, 2);
T2f = normalizeRows(T2f);

5.4 Vertex tangents

Use a fixed reference axis projected into the tangent plane with a fallback axis when near-parallel.

ref = repmat([1 0 0], size(Nv,1), 1);
parallel = abs(sum(ref .* Nv, 2)) > 0.9;       % too aligned with x-axis
ref(parallel,:) = repmat([0 1 0], sum(parallel), 1);

T1v = ref - sum(ref .* Nv, 2) .* Nv;
T1v = normalizeRows(T1v);

T2v = cross(Nv, T1v, 2);
T2v = normalizeRows(T2v);

5.5 Degenerate handling

Any row with norm < eps should be set to [0 0 0] and logged (optional). This prevents NaN propagation.

Provide a private helper:

function X = normalizeRows(X)
n = vecnorm(X,2,2);
bad = (n < eps) | isnan(n);
n(bad) = 1;
X = X ./ n;
X(bad,:) = 0;
end

6. Method placement and responsibilities
6.1 In bct.manifold.frame (function)

Responsibilities:

Validate M has Vertices and Faces

Check cache validity (M.Geometry.Frame.Meta.Hash)

Compute frames if needed

Store into M.Geometry.Frame

Return M.Geometry.Frame (or return a copy)

6.2 In bct.Manifold (class)

Responsibilities:

Define Geometry as a struct or handle-like cache container

Ensure any mutation of Vertices/Faces invalidates cache

Two acceptable strategies:

Hash-checked lazy invalidation (simplest): never clear cache on mutation; let frame() detect changes via hash and recompute.

Eager invalidation: in set.Vertices and set.Faces, clear M.Geometry.Frame.

Given your request for simplicity, choose (1) initially; it minimizes coupling.

7. Acceptance criteria (tests)

Implement minimal unit tests / asserts:

Shapes

size(out.Face.N,1) == size(F,1)

size(out.Vertex.N,1) == size(V,1)

Unit norms (within tolerance)

abs(vecnorm(Nf,2,2) - 1) < 1e-6 except degenerate faces

same for Nv, T1, T2

Orthogonality

dot(N, T1) ≈ 0

dot(N, T2) ≈ 0

dot(T1, T2) ≈ 0

Right-handedness

cross(T1, T2) ≈ N (or cross(N,T1)=T2 depending on convention; be consistent)

Cache hits

Call bct.manifold.frame(M) twice without geometry change → second call should not rebuild surfaceMesh (you can test via a simple internal counter or a debug flag).

Cache invalidation

Modify a vertex coordinate → hash changes → recompute occurs.

8. Example usage (intended)
M = bct.Manifold(V, F);

% One-time compute + cache
fr = bct.manifold.frame(M);

% Later fast retrieval (no recompute)
fr2 = bct.manifold.frame(M);

% Access
Nf  = fr.Face.N;
T1f = fr.Face.T1;
T2f = fr.Face.T2;

Nv  = fr.Vertex.N;
T1v = fr.Vertex.T1;
T2v = fr.Vertex.T2;

9. Non-goals (explicitly excluded for now)

UV-aligned tangents

multiple tangent construction methods

edge-based frames

transport / connections / DEC forms