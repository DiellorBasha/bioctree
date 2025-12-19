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
    end
end
