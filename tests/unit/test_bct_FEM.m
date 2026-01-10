classdef test_bct_FEM < BaseBctTest
    % TEST_BCT_FEM Unit tests for bct.FEM construction
    %
    % Tests FEM object creation from Manifold:
    % - Constructor accepts Manifold argument
    % - FEM object is created successfully
    % - Basic object properties accessible
    %
    % Does NOT test operators, computations, or eigensolver

    methods (Test)
        %% Constructor Tests
        function testFEMCreationFromManifold(testCase)
            % Verify FEM can be created from Manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fem = M.FEM();
            
            testCase.verifyNotEmpty(fem, ...
                'FEM should be created from Manifold');
            testCase.verifyClass(fem, 'bct.FEM', ...
                'Should return bct.FEM instance');
        end
        
        function testFEMCreationViaPort(testCase)
            % Verify FEM accessed through Manifold port method
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fem1 = M.FEM();
            fem2 = M.FEM();
            
            testCase.verifyEqual(fem1, fem2, ...
                'Multiple FEM() calls should return same cached instance');
        end
        
        function testFEMFromDifferentManifolds(testCase)
            % Verify different manifolds create different FEM objects
            mesh1 = bct.data.load("fsaverage6_hemi-lh_surf-pial");
            mesh2 = bct.data.load("fsaverage6_hemi-rh_surf-pial");
            
            M1 = bct.Manifold(mesh1.V, mesh1.F);
            M2 = bct.Manifold(mesh2.V, mesh2.F);
            
            fem1 = M1.FEM();
            fem2 = M2.FEM();
            
            testCase.verifyNotEqual(fem1, fem2, ...
                'FEM objects from different manifolds should be distinct');
        end
        
        %% Object Type Tests
        function testFEMIsHandle(testCase)
            % Verify FEM is a handle class
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            testCase.verifyTrue(isa(fem, 'handle'), ...
                'FEM should be a handle class');
        end
        
        function testFEMHasCoreProperties(testCase)
            % Verify FEM has core properties
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            testCase.verifyTrue(isprop(fem, 'Manifold'), ...
                'FEM should have Manifold property');
            testCase.verifyTrue(isprop(fem, 'Mass'), ...
                'FEM should have Mass property');
            testCase.verifyTrue(isprop(fem, 'Stiffness'), ...
                'FEM should have Stiffness property');
            testCase.verifyTrue(isprop(fem, 'MassType'), ...
                'FEM should have MassType property');
            
            % Verify Manifold reference is correct
            testCase.verifyEqual(fem.Manifold, M, ...
                'FEM should reference its source Manifold');
        end
        
        %% Multiple Instance Tests
        function testMultipleFEMInstancesFromSameManifold(testCase)
            % Verify FEM caching works (same instance returned)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fem1 = M.FEM();
            fem2 = M.FEM();
            fem3 = M.FEM();
            
            testCase.verifyEqual(fem1, fem2, ...
                'First and second FEM calls should return same instance');
            testCase.verifyEqual(fem2, fem3, ...
                'Second and third FEM calls should return same instance');
        end
        
        function testFEMIndependenceAcrossManifolds(testCase)
            % Verify FEM objects are independent across different Manifolds
            [V, F] = testCase.getDefaultTestMesh();
            
            M1 = bct.Manifold(V, F);
            M2 = bct.Manifold(V, F);
            
            fem1 = M1.FEM();
            fem2 = M2.FEM();
            
            % Even though manifolds have same geometry, FEM objects should be distinct
            testCase.verifyNotEqual(fem1, fem2, ...
                'FEM objects from different Manifold instances should be distinct');
        end
        
        %% Matrix Property Tests
        function testMassMatrixProperties(testCase)
            % Verify mass matrix has correct properties
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            Mass = fem.Mass();
            
            testCase.verifySize(Mass, [M.numVertices(), M.numVertices()], ...
                'Mass matrix should be [Nv×Nv]');
            testCase.verifyTrue(issparse(Mass), ...
                'Mass matrix should be sparse');
            testCase.verifyTrue(all(diag(Mass) > 0), ...
                'Mass matrix diagonal should be positive');
        end
        
        function testStiffnessMatrixProperties(testCase)
            % Verify stiffness matrix has correct properties
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            Stiff = fem.Stiffness();
            
            testCase.verifySize(Stiff, [M.numVertices(), M.numVertices()], ...
                'Stiffness matrix should be [Nv×Nv]');
            testCase.verifyTrue(issparse(Stiff), ...
                'Stiffness matrix should be sparse');
            testCase.verifyEqual(Stiff, Stiff', ...
                'Stiffness matrix should be symmetric');
        end
        
        function testLaplacianMatrixProperties(testCase)
            % Verify Laplacian matrix has correct properties
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            L = fem.Laplacian();
            
            testCase.verifySize(L, [M.numVertices(), M.numVertices()], ...
                'Laplacian should be [Nv×Nv]');
            testCase.verifyTrue(issparse(L), ...
                'Laplacian should be sparse');
            testCase.verifyEqual(L, L', ...
                'Laplacian should be symmetric');
            
            % Check row sums are zero
            rowSums = sum(L, 2);
            testCase.verifyLessThan(max(abs(rowSums)), 1e-10, ...
                'Laplacian row sums should be zero');
        end
        
        function testGradientMatrixDimensions(testCase)
            % Verify gradient matrix has correct dimensions
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            G = fem.Gradient();
            
            testCase.verifySize(G, [M.numFaces(), M.numVertices()], ...
                'Gradient should be [Nf×Nv]');
            testCase.verifyTrue(issparse(G), ...
                'Gradient should be sparse');
        end
        
        function testDivergenceMatrixDimensions(testCase)
            % Verify divergence matrix has correct dimensions
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            D = fem.Divergence();
            
            testCase.verifySize(D, [M.numVertices(), M.numFaces()], ...
                'Divergence should be [Nv×Nf]');
            testCase.verifyTrue(issparse(D), ...
                'Divergence should be sparse');
        end
        
        %% Mass Type Tests
        function testMassTypeVoronoi(testCase)
            % Verify FEM can use Voronoi mass matrix
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fem = bct.FEM(M, 'MassType', 'voronoi');
            
            testCase.verifyEqual(fem.MassType, "voronoi", ...
                'Mass type should be voronoi');
        end
        
        function testMassTypeBarycentric(testCase)
            % Verify FEM can use barycentric mass matrix
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fem = bct.FEM(M, 'MassType', 'barycentric');
            
            testCase.verifyEqual(fem.MassType, "barycentric", ...
                'Mass type should be barycentric');
        end
        
        function testMassTypeFull(testCase)
            % Verify FEM can use full mass matrix
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fem = bct.FEM(M, 'MassType', 'full');
            
            testCase.verifyEqual(fem.MassType, "full", ...
                'Mass type should be full');
        end
        
        %% Eigenpairs Tests
        function testFEMEigenpairsComputation(testCase)
            % Verify FEM can compute eigenpairs
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            k = 10;
            E = fem.eigenpairs(k);
            
            testCase.verifyClass(E, 'bct.Eigenpairs', ...
                'Should return Eigenpairs object');
            testCase.verifyEqual(E.k, k, ...
                'Should have k eigenpairs');
        end
        
        function testFEMEigenpairsMOrthonormality(testCase)
            % Verify eigenpairs are M-orthonormal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            E = fem.eigenpairs(10);
            Mass = fem.Mass();
            
            % Check M-orthonormality: Psi' * M * Psi = I
            I_approx = E.Vectors' * Mass * E.Vectors;
            testCase.verifyLessThan(norm(I_approx - eye(E.k), 'fro'), 1e-8, ...
                'Eigenvectors should be M-orthonormal');
        end
        
        %% Operator Application Tests
        function testApplyLaplacian(testCase)
            % Verify Laplacian can be applied to fields
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            % Create test field
            f = rand(M.numVertices(), 1);
            
            % Apply Laplacian
            Lf = fem.applyLaplacian(f);
            
            testCase.verifySize(Lf, size(f), ...
                'Laplacian output should match input size');
        end
        
        function testApplyGradient(testCase)
            % Verify gradient can be applied to scalar fields
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            % Create test scalar field
            f = rand(M.numVertices(), 1);
            
            % Apply gradient
            G = fem.Gradient();
            gradF = G * f;
            
            testCase.verifySize(gradF, [M.numFaces(), 1], ...
                'Gradient should produce face-based values');
        end
    end
end
