classdef PerfEigenSolve < matlab.unittest.TestCase
    % PERFEIGENSOLVE Performance tests for eigendecomposition operations
    %
    % Benchmarks:
    % - Eigenvalue solver performance vs mesh size
    % - Memory usage scaling
    % - Sparse vs dense methods
    % - Different Laplacian types
    
    properties (TestParameter)
        IcosphereLevel = {2, 3, 4}
        EigenmodeCount = {50, 100, 200, 500}
        LaplacianType = {'combinatorial', 'normalized'}
    end
    
    %% Eigendecomposition Performance Tests
    methods (Test)
        function testEigenSolveTime(testCase, IcosphereLevel, EigenmodeCount)
            % Benchmark eigendecomposition time vs mesh size
            
            [V, F] = icosphere(IcosphereLevel);
            M = bct.Manifold(V, F);
            
            % Skip if requesting more modes than vertices
            if EigenmodeCount > M.N
                testCase.assumeFail('Skipping: k > N');
                return;
            end
            
            % Time the eigendecomposition
            tic;
            M.meshFourier(EigenmodeCount);
            elapsed = toc;
            
            % Report performance
            fprintf('Eigensolve: N=%d, k=%d, time=%.3f sec (%.1f ms per mode)\n', ...
                M.N, EigenmodeCount, elapsed, 1000*elapsed/EigenmodeCount);
            
            % Performance assertions
            time_per_mode = elapsed / EigenmodeCount;
            testCase.verifyLessThan(time_per_mode, 0.5, ...
                'Eigensolve should be < 500ms per mode on average');
            
            % Verify correctness
            testCase.verifyEqual(length(M.Eigenvalues), EigenmodeCount);
            testCase.verifyTrue(issorted(M.Eigenvalues));
        end
        
        function testEigenSolveMemory(testCase, IcosphereLevel)
            % Benchmark memory usage for eigendecomposition
            
            [V, F] = icosphere(IcosphereLevel);
            M = bct.Manifold(V, F);
            
            k = min(100, M.N);
            
            % Memory before
            mem_before = memory;
            mem_start = mem_before.MemUsedMATLAB;
            
            % Perform eigendecomposition
            M.meshFourier(k);
            
            % Memory after
            mem_after = memory;
            mem_end = mem_after.MemUsedMATLAB;
            
            mem_used_mb = (mem_end - mem_start) / 1024^2;
            
            fprintf('Eigensolve memory: N=%d, k=%d, memory=%.2f MB\n', ...
                M.N, k, mem_used_mb);
            
            % Memory should scale reasonably
            % Eigenvectors: N × k doubles = 8*N*k bytes
            expected_mb = 8 * M.N * k / 1024^2;
            
            testCase.verifyLessThan(mem_used_mb, 5*expected_mb, ...
                'Memory usage should be within 5x expected size');
        end
    end
    
    %% Laplacian Type Comparison Tests
    methods (Test)
        function testLaplacianTypePerformance(testCase, LaplacianType)
            % Compare performance of different Laplacian types
            
            [V, F] = icosphere(3);
            M = bct.Manifold(V, F);
            M.lap_type = LaplacianType;
            
            k = 100;
            
            tic;
            M.meshFourier(k);
            elapsed = toc;
            
            fprintf('Laplacian type "%s": time=%.3f sec\n', LaplacianType, elapsed);
            
            testCase.verifyLessThan(elapsed, 10, ...
                sprintf('%s Laplacian should complete quickly', LaplacianType));
        end
    end
    
    %% Scaling Tests
    methods (Test)
        function testScalingWithMeshSize(testCase)
            % Test scaling of eigensolve with mesh size
            
            levels = [1, 2, 3];
            times = zeros(size(levels));
            sizes = zeros(size(levels));
            k = 50;
            
            for i = 1:length(levels)
                [V, F] = icosphere(levels(i));
                M = bct.Manifold(V, F);
                sizes(i) = M.N;
                
                tic;
                M.meshFourier(k);
                times(i) = toc;
                
                fprintf('Level %d: N=%d, time=%.3f sec\n', ...
                    levels(i), M.N, times(i));
            end
            
            % Plot scaling (if visualization enabled)
            if ~isempty(getenv('DISPLAY')) || ispc
                figure('Visible', 'off');
                plot(sizes, times, 'o-', 'LineWidth', 2);
                xlabel('Number of vertices (N)');
                ylabel('Time (seconds)');
                title(sprintf('Eigendecomposition Scaling (k=%d)', k));
                grid on;
                saveas(gcf, 'perf_eigensolve_scaling.png');
                close(gcf);
            end
            
            % Time should scale sub-quadratically
            % For sparse methods, expected O(N*k) to O(N*k*log(N))
            testCase.verifyLessThan(times(end)/times(1), (sizes(end)/sizes(1))^2, ...
                'Scaling should be better than O(N^2)');
        end
        
        function testScalingWithEigenmodes(testCase)
            % Test scaling with number of eigenmodes
            
            [V, F] = icosphere(2);
            M = bct.Manifold(V, F);
            
            k_values = [10, 25, 50, 100];
            times = zeros(size(k_values));
            
            for i = 1:length(k_values)
                k = k_values(i);
                if k > M.N
                    continue;
                end
                
                M_temp = bct.Manifold(V, F);  % Fresh copy
                tic;
                M_temp.meshFourier(k);
                times(i) = toc;
                
                fprintf('k=%d: time=%.3f sec (%.1f ms per mode)\n', ...
                    k, times(i), 1000*times(i)/k);
            end
            
            % Time per mode should be relatively constant
            time_per_mode = times ./ k_values;
            variation = std(time_per_mode(times > 0)) / mean(time_per_mode(times > 0));
            
            testCase.verifyLessThan(variation, 0.5, ...
                'Time per mode should be relatively constant (CoV < 0.5)');
        end
    end
    
    %% Sparse Matrix Performance Tests
    methods (Test)
        function testSparseLaplacianEfficiency(testCase)
            % Test that sparse Laplacian is more efficient than dense
            
            [V, F] = icosphere(3);
            M = bct.Manifold(V, F);
            M.computeLaplacian();
            
            % Verify Laplacian is sparse
            testCase.verifyTrue(issparse(M.L), 'Laplacian should be sparse');
            
            % Check sparsity ratio
            sparsity = nnz(M.L) / numel(M.L);
            fprintf('Laplacian sparsity: %.2f%% non-zero\n', 100*sparsity);
            
            testCase.verifyLessThan(sparsity, 0.05, ...
                'Laplacian should be highly sparse (< 5%% non-zero)');
        end
    end
    
    %% Accuracy Tests
    methods (Test)
        function testEigenvalueAccuracy(testCase)
            % Test accuracy of computed eigenvalues
            
            [V, F] = icosphere(2);
            M = bct.Manifold(V, F);
            k = 50;
            M.meshFourier(k);
            
            % Check Rayleigh quotient for each eigenmode
            % lambda_k = u_k' * L * u_k / (u_k' * u_k)
            L = M.L;
            
            for i = 1:min(10, k)  % Check first 10 modes
                u = M.Eigenvectors(:, i);
                lambda_computed = M.Eigenvalues(i);
                
                lambda_rayleigh = (u' * L * u) / (u' * u);
                
                testCase.verifyEqual(lambda_rayleigh, lambda_computed, 'RelTol', 1e-6, ...
                    sprintf('Eigenvalue %d should satisfy Rayleigh quotient', i));
            end
        end
        
        function testOrthogonalityAccuracy(testCase)
            % Test orthogonality of eigenvectors
            
            [V, F] = icosphere(2);
            M = bct.Manifold(V, F);
            k = 50;
            M.meshFourier(k);
            
            U = M.Eigenvectors;
            UU = U' * U;
            I = eye(k);
            
            error = norm(UU - I, 'fro');
            
            fprintf('Orthogonality error (Frobenius norm): %.2e\n', error);
            
            testCase.verifyLessThan(error, 1e-10, ...
                'Eigenvectors should be orthonormal');
        end
    end
    
    %% Comparison with Direct Methods
    methods (Test)
        function testCompareWithEIG(testCase)
            % Compare eigs (sparse) vs eig (dense) for small problem
            
            [V, F] = icosphere(1);  % Small mesh
            M = bct.Manifold(V, F);
            M.computeLaplacian();
            L = M.L;
            
            if M.N < 100  % Only for small problems
                k = min(20, M.N);
                
                % Sparse method (eigs)
                tic;
                [~, lambda_sparse] = eigs(L, k, 'smallestabs');
                time_sparse = toc;
                lambda_sparse = sort(diag(lambda_sparse));
                
                % Dense method (eig)
                tic;
                lambda_dense = sort(eig(full(L)));
                time_dense = toc;
                lambda_dense = lambda_dense(1:k);
                
                fprintf('Sparse (eigs): %.4f sec, Dense (eig): %.4f sec\n', ...
                    time_sparse, time_dense);
                
                % Results should match
                testCase.verifyEqual(lambda_sparse, lambda_dense, 'RelTol', 1e-6, ...
                    'Sparse and dense eigensolvers should agree');
                
                % Sparse should be faster for this size
                testCase.verifyLessThan(time_sparse, 2*time_dense, ...
                    'Sparse method should be competitive');
            end
        end
    end
end
