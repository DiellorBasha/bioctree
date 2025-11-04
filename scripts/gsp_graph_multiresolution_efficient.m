function [Gs]=gsp_graph_multiresolution_efficient(G,num_levels,param)
%GSP_GRAPH_MULTIRESOLUTION_EFFICIENT  Memory-efficient multiresolution of graphs
%   Usage:  [Gs]=gsp_graph_multiresolution_efficient(G,num_levels);
%           [Gs]=gsp_graph_multiresolution_efficient(G,num_levels,param);
%
%   This is a memory-efficient version of gsp_graph_multiresolution that uses
%   block-based approximate Schur complement computation instead of exact
%   Kron reduction to avoid memory explosion for large graphs.
%
%   Input parameters:
%         G           : Graph structure
%         num_levels  : Number of times to downsample and coarsen the graph
%         param       : Optional structure of parameters
%   Output parameters:
%         Gs          : Cell array of graphs
%         
%   Parameters (same as original plus new ones):
%   * *sparsify*: To perform a spectral sparsification step immediately
%     after the graph reduction (default=1) 
%   * *sparsify_epsilon*: Parameter epsilon used in the spectral
%     sparsification (default=min(10/sqrt(G.N),.3))   
%   * *downsampling_method*: The graph downsampling method
%     (default='largest_eigenvector') 
%   * *reduction_method*: The graph reduction method (default='efficient_kron')
%   * *compute_full_eigen*: To also compute the graph Laplacian eigenvalues
%     and eigenvectors for every graph in the multiresolution sequence
%     (default=0)  
%   
%   New parameters for efficient reduction:
%   * *block_size*: Block size for approximate solves (default=512)
%   * *pcg_tol*: PCG tolerance for approximate solves (default=1e-3)
%   * *drop_tol*: Threshold for dropping small entries (default=1e-6)
%   * *max_entries_per_row*: Maximum entries to keep per row (default=32)
%   * *ichol_droptol*: Incomplete Cholesky drop tolerance (default=1e-3)

if nargin < 3
    param = struct;
end

% Original parameters
if ~isfield(param,'sparsify'), param.sparsify = 1; end
if ~isfield(param,'compute_full_eigen'), param.compute_full_eigen = 0; end
if ~isfield(param,'sparsify_epsilon'), param.sparsify_epsilon = min(10/sqrt(G.N),.3); end
if ~isfield(param,'downsampling_method'), param.downsampling_method='largest_eigenvector'; end
if ~isfield(param,'reduction_method'), param.reduction_method='efficient_kron'; end

% New parameters for efficient reduction
if ~isfield(param,'block_size'), param.block_size = 512; end
if ~isfield(param,'pcg_tol'), param.pcg_tol = 1e-3; end
if ~isfield(param,'drop_tol'), param.drop_tol = 1e-6; end
if ~isfield(param,'max_entries_per_row'), param.max_entries_per_row = 32; end
if ~isfield(param,'ichol_droptol'), param.ichol_droptol = 1e-3; end

% Ensure lmax is computed for eigenvetor calculation
if param.compute_full_eigen
    if (~isfield(G,'U') || ~isfield(G,'e') )
        G=gsp_compute_fourier_basis(G);
    end
else
    if ~isfield(G,'lmax')
        G=gsp_estimate_lmax(G);
    end
end

% Set up cell for multiresolutions of graphs
Gs=cell(num_levels+1,1);
Gs{1}=G;
Gs{1}.mr.idx=(1:Gs{1}.N)';
Gs{1}.mr.orig_idx=Gs{1}.mr.idx;

if param.compute_full_eigen
    if (~isfield(Gs{1},'U') || ~isfield(Gs{1},'e') )
        Gs{1}=gsp_compute_fourier_basis(Gs{1});
    end
else
    if ~isfield(Gs{1},'lmax')
        Gs{1}=gsp_estimate_lmax(Gs{1});
    end
end

for lev=1:num_levels
    fprintf('Computing level %d/%d (current: %d vertices)...\n', lev, num_levels, Gs{lev}.N);
    
    Gs{lev+1}.directed=0;
    
    % Graph downsampling: get indices to keep for the new lower resolution graph
    switch param.downsampling_method
        case 'largest_eigenvector'
            if isfield(Gs{lev},'U')
                largest_eigenvector = Gs{lev}.U(:,Gs{lev}.N);
            else
                [largest_eigenvector,~]=eigs(Gs{lev}.L,1,'largestreal'); 
            end
            largest_eigenvector=largest_eigenvector*sign(largest_eigenvector(1));
            nonnegative_logicals=(largest_eigenvector >= 0);
            if sum(nonnegative_logicals) == 0
                error('Too many pyramid levels. Try fewer.');
            end
            keep_inds=find(nonnegative_logicals);
            
        otherwise
            error('Unknown graph downsampling method');
    end
    
    fprintf('  Downsampling: %d -> %d vertices (%.1f%% kept)\n', ...
        Gs{lev}.N, length(keep_inds), 100*length(keep_inds)/Gs{lev}.N);
   
    % Graph reduction: efficient Schur complement
    switch param.reduction_method
        case 'efficient_kron'
            % Use efficient block-based approximate Schur complement
            tic;
            Gs{lev+1}.L = efficient_schur_complement(Gs{lev}.L, keep_inds, param);
            reduction_time = toc;
            fprintf('  Efficient reduction completed in %.2f seconds\n', reduction_time);
            
        case 'kron'
            % Original Kron reduction (for comparison/fallback)
            warning('Using original Kron reduction - may cause memory issues for large graphs');
            Gs{lev+1}.L=gsp_kron_reduce(Gs{lev}.L,keep_inds);
          
        otherwise
            error('Unknown graph reduction method');
    end
 
    % Create the new graph from the reduced weighted adjacency matrix 
    Gs{lev+1}.N=size(Gs{lev+1}.L,1);
    
    % Report sparsity
    nnz_before = nnz(Gs{lev}.L);
    nnz_after = nnz(Gs{lev+1}.L);
    sparsity_before = 100*nnz_before/numel(Gs{lev}.L);
    sparsity_after = 100*nnz_after/numel(Gs{lev+1}.L);
    
    fprintf('  Sparsity: %.4f%% -> %.4f%% (nnz: %d -> %d)\n', ...
        sparsity_before, sparsity_after, nnz_before, nnz_after);
    
    % Check if adjacency matrix is connected
    Gs{lev+1}.W=max(Gs{lev+1}.L,Gs{lev+1}.L')-diag(diag(Gs{lev+1}.L));
    Gs{lev+1}.W=-Gs{lev+1}.W;
    
    % Sparsification step
    if param.sparsify
        if exist('gsp_graph_sparsify','file')
            Gs{lev+1}=gsp_graph_sparsify(Gs{lev+1},param.sparsify_epsilon);
            fprintf('  Sparsification applied (epsilon=%.4f)\n', param.sparsify_epsilon);
        else
            warning('gsp_graph_sparsify not found, skipping sparsification');
        end
    end

    % Set coordinates for plotting (subsample from parent)
    if isfield(Gs{lev},'coords')
        Gs{lev+1}.coords=Gs{lev}.coords(keep_inds,:);
    end
    
    % Multiresolution bookkeeping
    Gs{lev+1}.mr.idx=keep_inds;
    if isfield(Gs{lev},'mr') && isfield(Gs{lev}.mr,'orig_idx')
        Gs{lev+1}.mr.orig_idx=Gs{lev}.mr.orig_idx(keep_inds);
    else
        Gs{lev+1}.mr.orig_idx=keep_inds;
    end

    % Handle eigendecomposition
    if param.compute_full_eigen
        if exist('gsp_compute_fourier_basis','file')
            Gs{lev+1}=gsp_compute_fourier_basis(Gs{lev+1});
        end
    else
        if exist('gsp_estimate_lmax','file')
            Gs{lev+1}=gsp_estimate_lmax(Gs{lev+1});
        end
    end
end

fprintf('✓ Multiresolution pyramid completed: %d levels\n', num_levels);

end

function Lred = efficient_schur_complement(L, keep_inds, param)
%EFFICIENT_SCHUR_COMPLEMENT Compute Schur complement using block-based approach
%   This function computes the Schur complement L_KK - L_KR * inv(L_RR) * L_RK
%   efficiently using block-based approximate solves to avoid memory explosion.

% Partition indices
K = keep_inds(:);
N = size(L,1);
R = setdiff((1:N)', K);

% Extract blocks
LKK = L(K,K);
LKR = L(K,R);
LRK = L(R,K);
LRR = L(R,R);

fprintf('    Block sizes: K=%d, R=%d\n', length(K), length(R));

% Check if R block is empty
if isempty(R)
    Lred = LKK;
    return;
end

% Reorder RR for less fill-in
p = symamd(LRR); 
LRR = LRR(p,p); 
LKR = LKR(:,p); 
LRK = LRK(p,:);

fprintf('    Computing incomplete Cholesky preconditioner...\n');

% Preconditioner for approximate solves
try
    setup.type = 'ict';
    setup.droptol = param.ichol_droptol;
    P = ichol(LRR, setup);
catch ME
    fprintf('    Warning: ichol failed (%s), using no preconditioner\n', ME.message);
    P = [];
end

% Block-based approximate solving
blk = param.block_size;
nb = ceil(size(LRK,2)/blk);
tau = param.drop_tol;
kmax = param.max_entries_per_row;

fprintf('    Solving %d blocks of size ~%d...\n', nb, blk);

% Initialize result
Lred = LKK;

for b = 1:nb
    cols = ((b-1)*blk + 1) : min(b*blk, size(LRK,2));
    B = LRK(:, cols);
    Xb = zeros(size(B));
    
    % Solve each column approximately
    for j = 1:size(B,2)
        if ~isempty(P)
            [xj, flag] = pcg(LRR, B(:,j), param.pcg_tol, 100, P, P');
        else
            [xj, flag] = pcg(LRR, B(:,j), param.pcg_tol, 100);
        end
        
        if flag ~= 0 && flag ~= 1
            fprintf('    Warning: PCG did not converge for column %d (flag=%d)\n', j, flag);
        end
        
        Xb(:,j) = xj;
    end
    
    % Contribution to Schur complement: LKR * Xb
    C = LKR * Xb;
    
    % Sparsify on-the-fly
    C(abs(C) < tau) = 0;
    
    % Optional: keep top-k per row
    if kmax > 0
        C = keep_topk_per_row(C, kmax);
    end
    
    % Accumulate: LKK - LKR * inv(LRR) * LRK
    Lred(:, cols) = Lred(:, cols) - C;
end

% Symmetrize and ensure Laplacian structure (zero diagonal)
Lred = 0.5*(Lred + Lred.');
Lred = Lred - spdiags(diag(Lred), 0, size(Lred,1), size(Lred,2));

% Report final sparsity
nnz_original = nnz(LKK);
nnz_final = nnz(Lred);
fprintf('    Schur complement: %d -> %d non-zeros (%.2fx)\n', ...
    nnz_original, nnz_final, nnz_final/nnz_original);

end

function S2 = keep_topk_per_row(S, k)
%KEEP_TOPK_PER_ROW Keep top-k largest entries per row in sparse matrix
    [ii,jj,vv] = find(S);
    [~,ord] = sortrows([ii, -abs(vv)]);   % by row, descending |val|
    ii = ii(ord); jj = jj(ord); vv = vv(ord);
    cnt = accumarray(ii,1);
    cut = cumsum([0; cnt(1:end-1)]);
    keep = false(size(ii));
    
    for r = 1:numel(cut)
        s = cut(r)+1; 
        if r <= length(cnt)
            e = cut(r) + cnt(r);
        else
            e = length(ii);
        end
        
        if s <= e && cnt(r) > 0
            t = min(k, e-s+1);
            keep(s:s+t-1) = true;
        end
    end
    
    S2 = sparse(ii(keep), jj(keep), vv(keep), size(S,1), size(S,2));
end