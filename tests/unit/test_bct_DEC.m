classdef test_bct_DEC < BaseBctTest
    % TEST_BCT_DEC Unit tests for bct.DEC construction
    %
    % Tests DEC object creation from Manifold:
    % - Constructor accepts Manifold argument
    % - DEC object is created successfully
    % - Basic object properties accessible
    %
    % Does NOT test operators, differential forms, or computations

    methods (Test)
        %% Constructor Tests
        function testDECCreationFromManifold(testCase)
            % Verify DEC can be created from Manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            dec = M.DEC();
            
            testCase.verifyNotEmpty(dec, ...
                'DEC should be created from Manifold');
            testCase.verifyClass(dec, 'bct.DEC', ...
                'Should return bct.DEC instance');
        end
        
        function testDECCreationViaPort(testCase)
            % Verify DEC accessed through Manifold port method
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            dec1 = M.DEC();
            dec2 = M.DEC();
            
            testCase.verifyEqual(dec1, dec2, ...
                'Multiple DEC() calls should return same cached instance');
        end
        
        function testDECFromDifferentManifolds(testCase)
            % Verify different manifolds create different DEC objects
            mesh1 = bct.data.load("fsaverage6_hemi-lh_surf-pial");
            mesh2 = bct.data.load("fsaverage6_hemi-rh_surf-pial");
            
            M1 = bct.Manifold(mesh1.V, mesh1.F);
            M2 = bct.Manifold(mesh2.V, mesh2.F);
            
            dec1 = M1.DEC();
            dec2 = M2.DEC();
            
            testCase.verifyNotEqual(dec1, dec2, ...
                'DEC objects from different manifolds should be distinct');
        end
        
        %% Object Type Tests
        function testDECIsHandle(testCase)
            % Verify DEC is a handle class
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            dec = M.DEC();
            
            testCase.verifyTrue(isa(dec, 'handle'), ...
                'DEC should be a handle class');
        end
        
        function testDECHasCoreProperties(testCase)
            % Verify DEC has core properties
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            dec = M.DEC();
            
            testCase.verifyTrue(isprop(dec, 'Manifold'), ...
                'DEC should have Manifold property');
            testCase.verifyTrue(isprop(dec, 'Backend'), ...
                'DEC should have Backend property');
            
            % Verify Manifold reference is correct
            testCase.verifyEqual(dec.Manifold, M, ...
                'DEC should reference its source Manifold');
            
            % Verify Backend exists and is DiscreteExteriorCalculus
            testCase.verifyNotEmpty(dec.Backend, ...
                'DEC Backend should not be empty');
            testCase.verifyClass(dec.Backend, 'DiscreteExteriorCalculus', ...
                'Backend should be DiscreteExteriorCalculus from DECLab');
        end
        
        %% Multiple Instance Tests
        function testMultipleDECInstancesFromSameManifold(testCase)
            % Verify DEC caching works (same instance returned)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            dec1 = M.DEC();
            dec2 = M.DEC();
            dec3 = M.DEC();
            
            testCase.verifyEqual(dec1, dec2, ...
                'First and second DEC calls should return same instance');
            testCase.verifyEqual(dec2, dec3, ...
                'Second and third DEC calls should return same instance');
        end
        
        function testDECIndependenceAcrossManifolds(testCase)
            % Verify DEC objects are independent across different Manifolds
            [V, F] = testCase.getDefaultTestMesh();
            
            M1 = bct.Manifold(V, F);
            M2 = bct.Manifold(V, F);
            
            dec1 = M1.DEC();
            dec2 = M2.DEC();
            
            % Even though manifolds have same geometry, DEC objects should be distinct
            testCase.verifyNotEqual(dec1, dec2, ...
                'DEC objects from different Manifold instances should be distinct');
        end
    end
end
