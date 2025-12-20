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
    end
end
