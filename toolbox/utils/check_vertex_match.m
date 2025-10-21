function R = check_vertex_match(A_Vertices, G_coords, tol)
% CHECK_VERTEX_MATCH  Compare two vertex coordinate sets and recover index maps.
% R.same_size       : sizes match (N x 3)
% R.same_order      : coordinates match in the SAME order within tol
% R.same_set        : they contain the SAME multiset of points (order can differ)
% R.max_pair_error  : max ||G_coords(k,:) - A_Vertices(G2A(k),:)||2 after matching
% R.G2A             : index map (G index -> A index); 0 if unmatched
% R.A2G             : index map (A index -> G index); 0 if unmatched
% R.unmatched_G     : indices in G with no match in A (within tol)
% R.unmatched_A     : indices in A with no match in G (within tol)

if nargin < 3 || isempty(tol), tol = 1e-8; end
R = struct('same_size',false,'same_order',false,'same_set',false, ...
           'max_pair_error',NaN,'G2A',[],'A2G',[], ...
           'unmatched_G',[],'unmatched_A',[]);

% 0) Shape checks
if size(A_Vertices,2)~=3 || size(G_coords,2)~=3
    error('Inputs must be N×3 arrays.');
end
R.same_size = size(A_Vertices,1)==size(G_coords,1);

% 1) Quick same-order test (fast path)
if R.same_size
    err = sqrt(sum((A_Vertices - G_coords).^2, 2));
    R.same_order = all(err <= tol);
    if R.same_order
        N = size(G_coords,1);
        R.G2A = (1:N).'; R.A2G = (1:N).';
        R.max_pair_error = max(err);
        R.same_set = true;
        return
    end
end

% 2) Robust set-equality & permutation recovery
%    We use nearest-neighbor matching (1-NN) both ways with a tolerance.
%    This handles permutations; if duplicates exist, we then refine.
[idxA, dGA] = knnsearch(A_Vertices, G_coords, 'K', 1);
[idxG, dAG] = knnsearch(G_coords, A_Vertices, 'K', 1);

% Propose maps within tol
G2A = zeros(size(G_coords,1),1);    G2A(dGA<=tol) = idxA(dGA<=tol);
A2G = zeros(size(A_Vertices,1),1);  A2G(dAG<=tol) = idxG(dAG<=tol);

% Consistency pass (ensure mutual mapping where possible)
mutual = (A2G(G2A) == (1:numel(G2A)).');
G2A(~mutual & G2A~=0) = 0;  % drop non-mutual assignments

% Diagnostics
R.G2A = G2A;  R.A2G = A2G;
R.unmatched_G = find(G2A==0);
R.unmatched_A = find(A2G==0);

% Compute max pair error over matched pairs
matched = find(G2A>0);
if ~isempty(matched)
    diffs = G_coords(matched,:) - A_Vertices(G2A(matched),:);
    R.max_pair_error = max(sqrt(sum(diffs.^2,2)));
else
    R.max_pair_error = NaN;
end

% Set equality flag
R.same_set = isempty(R.unmatched_G) && isempty(R.unmatched_A);

end
