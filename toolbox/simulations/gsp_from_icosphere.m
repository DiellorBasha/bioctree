function Gg = gsp_from_icosphere(G0)
% GSP_FROM_ICOSPHERE  Build a GSPBox graph from build_icosphere(...) output.
% 
% Inputs (expected fields in G0):
%   .V [N×3]         vertex coordinates
%   .T or .F [M×3]   faces (optional; only used if we must build W)
%   .L [N×N]         Laplacian (optional, cotangent preferred)
%   .W [N×N]         adjacency (optional)
%   .R               sphere radius (optional; carried over)
%   .vertexArea [N×1] (optional; carried over)
%
% Output:
%   Gg   GSPBox graph with fields at least: W, coords, (and copies of L, R, vertexArea)

    assert(isfield(G0,'V') && ~isempty(G0.V), 'G0.V (Nx3) is required');
    V = G0.V; N = size(V,1);

    % --- Decide how to get W (weighted adjacency) ---
    if isfield(G0,'W') && ~isempty(G0.W)
        W = G0.W;
    elseif isfield(G0,'L') && ~isempty(G0.L)
        % If we have a cotangent-like Laplacian: off-diag L_ij = -w_ij, diag = sum w_ij
        L = (G0.L + G0.L')/2;
        W = -L;                                  % off-diagonals become weights
        W = W - spdiags(diag(W),0,N,N);          % zero diagonal
        % numerical cleanup
        W = max(W, 0);                           % clip tiny negatives
        W = (W + W')/2;                          % symmetrize
    else
        % Build a simple unweighted adjacency from faces if available
        assert(isfield(G0,'T') || isfield(G0,'F'), ...
            'Need G0.L or G0.W or faces (G0.T/G0.F) to build adjacency.');
        F = getfield(G0, ternary(isfield(G0,'T'),'T','F'));     %#ok<GFLD>
        I = [F(:,1); F(:,2); F(:,3)];
        J = [F(:,2); F(:,3); F(:,1)];
        W = sparse(I,J,1,N,N); W = W + W.';      % undirected, unweighted
        W = W - spdiags(diag(W),0,N,N);
    end

    % --- Build GSPBox graph ---
    Gg = gsp_graph(W, V);                        % coords = 3D
    % Carry over helpful metadata
    if isfield(G0,'L') && ~isempty(G0.L), Gg.L = (G0.L+G0.L')/2; end
    if isfield(G0,'R') && ~isempty(G0.R), Gg.R = G0.R; end
    if isfield(G0,'vertexArea') && ~isempty(G0.vertexArea), Gg.vertexArea = G0.vertexArea; end
end

function y = ternary(cond, a, b)
if cond, y = a; else, y = b; end
end
