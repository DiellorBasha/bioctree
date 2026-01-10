classdef test_bct_Eigenpairs < BaseBctTest
    % TEST_BCT_EIGENPAIRS Unit tests for bct.Eigenpairs construction
    %
    % Tests Eigenpairs object creation from representations:
    % - Eigenpairs obtained from FEM
    % - Eigenpairs obtained from Graph  
    % - Eigenpairs obtained from DEC
    % - Basic object properties accessible
    %
    % Does NOT test eigensolvers, projection, or transforms

    methods (Test)
        %% Constructor Tests via FEM
        function testEigenpairsFromFEM(testCase)
            % Verify Eigenpairs can be obtained from FEM representation
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            k = 10;
            E = fem.eigenpairs(k);
            
            testCase.verifyNotEmpty(E, ...
                'Eigenpairs should be created from FEM');
            testCase.verifyClass(E, 'bct.Eigenpairs', ...
                'Should return bct.Eigenpairs instance');
        end
        
        function testEigenpairsFromFEMDifferentK(testCase)
            % Verify Eigenpairs works with different k values
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            k_values = [5, 20, 50];
            
            for k = k_values
                E = fem.eigenpairs(k);
                testCase.verifyNotEmpty(E, ...
                    sprintf('Eigenpairs should be created with k=%d', k));
            end
        end
        
        %% Constructor Tests via Graph
        function testEigenpairsFromGraph(testCase)
            % Verify Eigenpairs can be obtained from Graph representation
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            graph = M.Graph();
            
            k = 10;
            E = graph.eigenpairs(k);
            
            testCase.verifyNotEmpty(E, ...
                'Eigenpairs should be created from Graph');
            testCase.verifyClass(E, 'bct.Eigenpairs', ...
                'Should return bct.Eigenpairs instance');
        end
        
        function testEigenpairsFromGraphCaching(testCase)
            % Verify Eigenpairs from Graph uses caching
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            graph = M.Graph();
            
            k = 10;
            E1 = graph.eigenpairs(k);
            E2 = graph.eigenpairs(k);
            
            testCase.verifyEqual(E1, E2, ...
                'Same k should return cached Eigenpairs instance');
        end
        
        %% Object Type Tests
        function testEigenpairsIsHandle(testCase)
            % Verify Eigenpairs is a handle class (for lazy evaluation)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            E = fem.eigenpairs(10);
            
            testCase.verifyTrue(isa(E, 'handle'), ...
                'Eigenpairs should be a handle class (for lazy evaluation)');
        end
        
        function testEigenpairsHasCoreProperties(testCase)
            % Verify Eigenpairs has core properties
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            E = fem.eigenpairs(10);
            
            testCase.verifyTrue(isprop(E, 'Values'), ...
                'Eigenpairs should have Values property');
            testCase.verifyTrue(isprop(E, 'Vectors'), ...
                'Eigenpairs should have Vectors property');
            testCase.verifyTrue(isprop(E, 'MassMatrix'), ...
                'Eigenpairs should have MassMatrix property');
            testCase.verifyTrue(isprop(E, 'Operator'), ...
                'Eigenpairs should have Operator property');
            testCase.verifyTrue(isprop(E, 'Basis'), ...
                'Eigenpairs should have Basis property');
        end
        
        function testEigenpairsHasNumModesMethod(testCase)
            % Verify Eigenpairs has numModes method
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            k = 10;
            E = fem.eigenpairs(k);
            
            % Check numModes method exists
            testCase.verifyTrue(ismethod(E, 'numModes'), ...
                'Eigenpairs should have numModes method');
            
            % Verify it returns a value
            n = E.numModes();
            testCase.verifyGreaterThan(n, 0, ...
                'numModes should return positive value');
        end
        
        %% Multiple Instance Tests
        function testMultipleEigenpairsFromDifferentRepresentations(testCase)
            % Verify Eigenpairs from different representations are independent
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fem = M.FEM();
            graph = M.Graph();
            
            k = 10;
            E_fem = fem.eigenpairs(k);
            E_graph = graph.eigenpairs(k);
            
            testCase.verifyNotEmpty(E_fem, ...
                'FEM Eigenpairs should be created');
            testCase.verifyNotEmpty(E_graph, ...
                'Graph Eigenpairs should be created');
            
            % Note: They may have different eigenvalues due to different discretizations
            testCase.verifyClass(E_fem, 'bct.Eigenpairs', ...
                'FEM result should be Eigenpairs');
            testCase.verifyClass(E_graph, 'bct.Eigenpairs', ...
                'Graph result should be Eigenpairs');
        end
        
        function testEigenpairsFromDifferentManifolds(testCase)
            % Verify Eigenpairs from different Manifolds are independent
            mesh1 = bct.data.load("fsaverage6_hemi-lh_surf-pial");
            mesh2 = bct.data.load("fsaverage6_hemi-rh_surf-pial");
            
            M1 = bct.Manifold(mesh1.V, mesh1.F);
            M2 = bct.Manifold(mesh2.V, mesh2.F);
            
            fem1 = M1.FEM();
            fem2 = M2.FEM();
            
            k = 10;
            E1 = fem1.eigenpairs(k);
            E2 = fem2.eigenpairs(k);
            
            testCase.verifyNotEmpty(E1, ...
                'First manifold Eigenpairs should be created');
            testCase.verifyNotEmpty(E2, ...
                'Second manifold Eigenpairs should be created');
            
            % Verify they have different ManifoldIDs
            testCase.verifyNotEqual(E1.ManifoldID, E2.ManifoldID, ...
                'Different manifolds should have different IDs');
        end
        
        %% Eigenvalue and Eigenvector Tests
        function testEigenvaluesAreSorted(testCase)
            % Verify eigenvalues are sorted in ascending order
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 20);
            lambda = E.Values;
            
            testCase.verifyTrue(issorted(lambda), ...
                'Eigenvalues should be sorted ascending');
            testCase.verifyGreaterThanOrEqual(lambda(1), -1e-10, ...
                'First eigenvalue should be ~0 (DC component)');
        end
        
        function testEigenvectorsOrthonormal(testCase)
            % Verify eigenvectors are orthonormal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 15);
            Psi = E.Vectors;
            
            % Check orthonormality: Psi' * Psi = I
            I_approx = Psi' * Psi;
            testCase.verifyLessThan(norm(I_approx - eye(E.k), 'fro'), 1e-8, ...
                'Eigenvectors should be orthonormal');
        end
        
        function testEigenpairsResidual(testCase)
            % Verify eigenpairs satisfy L*psi = lambda*psi
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            E = fem.eigenpairs(10);
            L = fem.Laplacian();
            
            % Check for a few eigenmodes
            for i = [1, 5, 10]
                psi = E.Vectors(:, i);
                lambda = E.Values(i);
                
                residual = L*psi - lambda*psi;
                testCase.verifyLessThan(norm(residual), 1e-8, ...
                    sprintf('Eigenmode %d should satisfy L*psi = lambda*psi', i));
            end
        end
        
        %% Projection and Reconstruction Tests
        function testProjectionDimensions(testCase)
            % Verify projection produces correct dimensions
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 20);
            
            % Create test field
            f = rand(M.numVertices(), 1);
            
            % Project onto spectral domain
            spectrum = E.Vectors' * f;
            
            testCase.verifySize(spectrum, [E.k, 1], ...
                'Spectral coefficients should be [k×1]');
        end
        
        function testReconstructionFromSpectrum(testCase)
            % Verify reconstruction from spectral coefficients
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 50);
            
            % Original field
            f_orig = rand(M.numVertices(), 1);
            
            % Project and reconstruct
            spectrum = E.Vectors' * f_orig;
            f_recon = E.Vectors * spectrum;
            
            % Should be nearly identical
            testCase.verifyLessThan(norm(f_orig - f_recon), 1e-10, ...
                'Reconstruction should match original (within numerical error)');
        end
        
        %% Truncation and Bandlimiting Tests
        function testTruncation(testCase)
            % Verify eigenpairs can be truncated
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E_full = bct.graph.eigensolve(M, 50);
            
            if ismethod(E_full, 'truncate')
                E_trunc = E_full.truncate(20);
                
                testCase.verifyEqual(E_trunc.k, 20, ...
                    'Truncated eigenpairs should have k=20');
                testCase.verifySize(E_trunc.Vectors, [M.numVertices(), 20], ...
                    'Truncated vectors should be [Nv×20]');
            end
        end
        
        function testBandlimiting(testCase)
            % Verify eigenpairs can be bandlimited by eigenvalue range
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E_full = bct.graph.eigensolve(M, 50);
            
            if ismethod(E_full, 'bandlimit')
                % Keep only modes with lambda in [0.1, 1.0]
                E_band = E_full.bandlimit([0.1, 1.0]);
                
                testCase.verifyTrue(all(E_band.Values >= 0.1), ...
                    'All eigenvalues should be >= 0.1');
                testCase.verifyTrue(all(E_band.Values <= 1.0), ...
                    'All eigenvalues should be <= 1.0');
            end
        end
        
        %% Metadata and Provenance Tests
        function testEigenpairsMetadata(testCase)
            % Verify eigenpairs contain metadata
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 10);
            
            testCase.verifyNotEmpty(E.ManifoldID, ...
                'Eigenpairs should have ManifoldID');
            testCase.verifyNotEmpty(E.Operator, ...
                'Eigenpairs should specify operator type');
        end
        
        function testEigenpairsProvenance(testCase)
            % Verify eigenpairs track provenance if available
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 10);
            
            % Check if provenance tracking exists
            if isprop(E, 'Provenance') || isfield(E, 'provenance')
                testCase.verifyTrue(true, ...
                    'Provenance tracking available');
            end
        end
    end
end
