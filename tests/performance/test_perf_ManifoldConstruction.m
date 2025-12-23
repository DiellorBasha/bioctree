classdef test_perf_ManifoldConstruction < BaseBctTest
    % TEST_PERF_MANIFOLDCONSTRUCTION Performance tests for Manifold construction
    %
    % Tests performance of Manifold object creation with different mesh sizes:
    % - Construction time should scale linearly with mesh size
    % - Edge computation should be efficient
    % - No eager FEM/eigenpair computation
    % - Lazy initialization of representations
    %
    % Performance Requirements (from FEM and Eigenpairs policy):
    % - FEM eigensolver ("eigs" function, solveGeneralized) should NOT be
    %   initiated on construction but computed lazily
    % - Manifold construction should be dominated by edge extraction only
    %
    % Expected Performance:
    % - Small mesh (100 vertices): < 0.1s
    % - Medium mesh (10k vertices): < 0.5s
    % - Large mesh (163k vertices, fsaverage6): < 3.5s
    %
    % See also: bct.Manifold, bct.FEM, bct.Eigenpairs
    
    properties (TestParameter)
        % Test different mesh sizes
        MeshSize = struct(...
            'tiny', 100, ...
            'small', 1000, ...
            'medium', 10000)
    end
    
    methods (Test)
        %% Construction Time Tests
        
        function testConstructionTimeDefault(testCase)
            % Test Manifold construction time with default fsaverage6 mesh
            % This is the primary use case and should complete reasonably fast
            
            % Load mesh
            mesh = bct.data.load();
            nVertices = size(mesh.Vertices, 1);
            
            % Time construction
            tic;
            M = bct.Manifold(mesh);
            constructionTime = toc;
            
            % Verify construction completed
            testCase.verifyNotEmpty(M, 'Manifold should be created');
            
            % Log performance
            fprintf('  [PERF] Manifold construction (%d vertices): %.3f s\n', ...
                nVertices, constructionTime);
            
            % Performance assertion: < 3.5s for fsaverage6 (163k vertices)
            testCase.verifyLessThan(constructionTime, 3.5, ...
                sprintf('Construction should complete in < 3.5s (actual: %.3f s)', constructionTime));
        end
        
        function testConstructionTimeScaling(testCase, MeshSize)
            % Test construction time scales appropriately with mesh size
            % Should be roughly linear in number of vertices
            
            % Generate synthetic mesh
            [V, F] = testCase.generateSyntheticMesh(MeshSize);
            
            % Time construction
            tic;
            M = bct.Manifold(V, F);
            constructionTime = toc;
            
            % Verify construction completed
            testCase.verifyNotEmpty(M, 'Manifold should be created');
            
            % Log performance
            fprintf('  [PERF] Manifold construction (%d vertices): %.3f s\n', ...
                size(V, 1), constructionTime);
            
            % Performance assertions based on size
            switch MeshSize
                case 100
                    threshold = 0.1;
                case 1000
                    threshold = 0.2;
                case 10000
                    threshold = 0.5;
                otherwise
                    threshold = 1.0;
            end
            
            testCase.verifyLessThan(constructionTime, threshold, ...
                sprintf('Construction should complete in < %.1f s for %d vertices (actual: %.3f s)', ...
                threshold, size(V, 1), constructionTime));
        end
        
        function testEdgeComputationTime(testCase)
            % Test that edge computation is the dominant cost in construction
            % This verifies that no heavy computation (FEM/eigenpairs) happens during construction
            
            mesh = bct.data.load();
            F = mesh.Faces;
            
            % Time just edge computation
            tic;
            edges = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
            edges = sort(edges, 2);
            E = unique(edges, 'rows');
            edgeTime = toc;
            
            % Time full construction
            tic;
            M = bct.Manifold(mesh);
            constructionTime = toc;
            
            % Log performance
            fprintf('  [PERF] Edge computation: %.3f s\n', edgeTime);
            fprintf('  [PERF] Full construction: %.3f s\n', constructionTime);
            fprintf('  [PERF] Overhead ratio: %.2fx\n', constructionTime / edgeTime);
            
            % Construction should be dominated by edge computation
            % Allow 3x overhead for other bookkeeping (ID generation, cache init, etc.)
            testCase.verifyLessThan(constructionTime, edgeTime * 3, ...
                sprintf('Construction overhead should be < 3x edge computation (edge: %.3f s, total: %.3f s)', ...
                edgeTime, constructionTime));
        end
        
        %% Lazy Initialization Tests
        
        function testNoEagerFEMConstruction(testCase)
            % Verify that FEM object is NOT created during Manifold construction
            % FEM should be created lazily on first M.FEM() call
            
            mesh = bct.data.load();
            
            % Time Manifold construction
            tic;
            M = bct.Manifold(mesh);
            constructionTime = toc;
            
            % Time first FEM access (includes FEM construction + matrix assembly)
            tic;
            fem = M.FEM();
            femAccessTime = toc;
            
            % Log performance
            fprintf('  [PERF] Manifold construction: %.3f s\n', constructionTime);
            fprintf('  [PERF] First FEM access: %.3f s\n', femAccessTime);
            
            % FEM access should take significantly longer than Manifold construction
            % if lazy initialization is working correctly
            testCase.verifyGreaterThan(femAccessTime, constructionTime, ...
                'FEM access should be slower than Manifold construction (indicating lazy initialization)');
            
            % Verify FEM was actually created
            testCase.verifyClass(fem, 'bct.FEM', 'Should return FEM object');
        end
        
        function testNoEagerEigensolve(testCase)
            % Verify that eigenpairs are NOT computed during Manifold construction
            % Eigensolver (eigs) should only run on explicit fem.eigenpairs(k) call
            
            mesh = bct.data.load();
            
            % Time Manifold + FEM construction
            tic;
            M = bct.Manifold(mesh);
            fem = M.FEM();
            setupTime = toc;
            
            % Time eigenpair computation (first call triggers eigensolve)
            % Note: Request k+1 to account for DC component removal
            k = 100;
            tic;
            E = fem.eigenpairs(k + 1);
            eigensolveTime = toc;
            
            % Log performance
            fprintf('  [PERF] Manifold + FEM setup: %.3f s\n', setupTime);
            fprintf('  [PERF] Eigensolve (%d modes requested): %.3f s\n', k + 1, eigensolveTime);
            fprintf('  [PERF] Actual modes returned: %d\n', numel(E.Values));
            
            % Eigensolve should take significant time on first call
            % (indicating it was not done during construction)
            % If it's too fast, eigenpairs may have been cached from a previous call
            testCase.verifyGreaterThan(eigensolveTime, 0.01, ...
                'Eigensolve should take measurable time (> 0.01s)');
            
            % Verify eigenpairs were computed (allow for DC removal)
            testCase.verifyClass(E, 'bct.Eigenpairs', 'Should return Eigenpairs object');
            testCase.verifyGreaterThanOrEqual(numel(E.Values), k, ...
                sprintf('Should compute at least %d eigenpairs (got %d)', k, numel(E.Values)));
        end
        
        function testRepresentationCaching(testCase)
            % Verify that representations are cached after first access
            % Second access should be nearly instantaneous
            
            mesh = bct.data.load();
            M = bct.Manifold(mesh);
            
            % First FEM access (triggers creation)
            tic;
            fem1 = M.FEM();
            firstAccessTime = toc;
            
            % Second FEM access (should return cached)
            tic;
            fem2 = M.FEM();
            secondAccessTime = toc;
            
            % Log performance
            fprintf('  [PERF] First FEM access: %.6f s\n', firstAccessTime);
            fprintf('  [PERF] Second FEM access: %.6f s\n', secondAccessTime);
            fprintf('  [PERF] Speedup: %.0fx\n', firstAccessTime / secondAccessTime);
            
            % Second access should be much faster (cached)
            testCase.verifyLessThan(secondAccessTime, firstAccessTime * 0.01, ...
                'Cached FEM access should be < 1% of initial creation time');
            
            % Verify same object is returned
            testCase.verifyEqual(fem1, fem2, 'Should return same cached FEM object');
        end
        
        %% Memory and Scaling Tests
        
        function testConstructionMemoryFootprint(testCase)
            % Verify Manifold construction doesn't allocate excessive memory
            % Should only store V, F, E and lightweight bookkeeping
            
            mesh = bct.data.load();
            
            % Estimate expected memory
            nVertices = size(mesh.Vertices, 1);
            nFaces = size(mesh.Faces, 1);
            expectedEdges = nFaces * 1.5; % Approximate for closed manifold
            
            % V: N×3 double, F: M×3 double, E: ~1.5M×2 double
            expectedBytes = (nVertices * 3 + nFaces * 3 + expectedEdges * 2) * 8;
            expectedMB = expectedBytes / 1e6;
            
            % Create Manifold
            M = bct.Manifold(mesh);
            
            % Check actual properties size
            actualEdges = size(M.Edges, 1);
            
            % Log memory info
            fprintf('  [MEMORY] Vertices: %d × 3 = %.2f MB\n', ...
                nVertices, nVertices * 3 * 8 / 1e6);
            fprintf('  [MEMORY] Faces: %d × 3 = %.2f MB\n', ...
                nFaces, nFaces * 3 * 8 / 1e6);
            fprintf('  [MEMORY] Edges: %d × 2 = %.2f MB\n', ...
                actualEdges, actualEdges * 2 * 8 / 1e6);
            fprintf('  [MEMORY] Expected total: ~%.2f MB\n', expectedMB);
            
            % Verify edge count is reasonable (within 50% of estimate)
            testCase.verifyLessThan(actualEdges, expectedEdges * 1.5, ...
                'Edge count should be reasonable for closed manifold');
        end
        
        function testMultipleManifoldCreation(testCase)
            % Test creating multiple Manifold objects
            % Verifies no global state interference
            
            mesh = bct.data.load();
            
            % Create multiple Manifolds
            tic;
            M1 = bct.Manifold(mesh);
            M2 = bct.Manifold(mesh);
            M3 = bct.Manifold(mesh);
            multipleCreationTime = toc;
            
            % Time single creation for comparison
            tic;
            M_single = bct.Manifold(mesh);
            singleCreationTime = toc;
            
            % Log performance
            fprintf('  [PERF] Single creation: %.3f s\n', singleCreationTime);
            fprintf('  [PERF] Triple creation: %.3f s (%.3f s each)\n', ...
                multipleCreationTime, multipleCreationTime / 3);
            
            % Each creation should take similar time (no cumulative overhead)
            avgTime = multipleCreationTime / 3;
            testCase.verifyLessThan(abs(avgTime - singleCreationTime), singleCreationTime * 0.5, ...
                'Average creation time should be consistent across multiple instances');
            
            % Verify unique IDs
            testCase.verifyNotEqual(M1.ID, M2.ID, 'Each Manifold should have unique ID');
            testCase.verifyNotEqual(M2.ID, M3.ID, 'Each Manifold should have unique ID');
        end
    end
    
    %% Test Utilities
    methods (Static)
        function [V, F] = generateSyntheticMesh(nVertices)
            % Generate synthetic mesh for performance testing
            % Uses sphere subdivision for realistic mesh structure
            
            if nVertices <= 100
                % Very small: low resolution sphere
                [x, y, z] = sphere(8);
            elseif nVertices <= 1000
                % Small: medium resolution sphere
                [x, y, z] = sphere(16);
            elseif nVertices <= 10000
                % Medium: high resolution sphere
                [x, y, z] = sphere(50);
            else
                % Large: very high resolution sphere
                [x, y, z] = sphere(100);
            end
            
            % Convert to V, F format
            V = [x(:), y(:), z(:)];
            
            % Generate triangular faces from grid
            [m, n] = size(x);
            F = [];
            for i = 1:m-1
                for j = 1:n-1
                    % Two triangles per grid cell
                    v1 = (i-1)*n + j;
                    v2 = (i-1)*n + j+1;
                    v3 = i*n + j;
                    v4 = i*n + j+1;
                    F = [F; v1 v2 v3; v2 v4 v3];
                end
            end
            
            % Trim to approximately requested size if needed
            if size(V, 1) > nVertices
                V = V(1:nVertices, :);
                % Remove faces referencing removed vertices
                F = F(all(F <= nVertices, 2), :);
            end
        end
    end
end
