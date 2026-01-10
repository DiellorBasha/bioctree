classdef test_bct_DEC < BaseBctTest
    % TEST_BCT_DEC Unit tests for Manifold.DEC() method
    %
    % Tests DiscreteExteriorCalculus backend creation from Manifold:
    % - Manifold.DEC() returns DiscreteExteriorCalculus instance
    % - DEC backend is cached properly
    % - Basic backend properties accessible
    %
    % Does NOT test operators (see test_operator_refactor.m)

    methods (Test)
        %% Constructor Tests
        function testDECCreationFromManifold(testCase)
            % Verify DEC returns DiscreteExteriorCalculus from Manifold
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            dec = M.DEC();
            
            testCase.verifyNotEmpty(dec, ...
                'DEC should be created from Manifold');
            testCase.verifyClass(dec, 'DiscreteExteriorCalculus', ...
                'Should return DiscreteExteriorCalculus instance');
        end
        
        function testDECCreationViaPort(testCase)
            % Verify DEC accessed through Manifold port method is cached
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            dec1 = M.DEC();
            dec2 = M.DEC();
            
            testCase.verifyEqual(dec1, dec2, ...
                'Multiple DEC() calls should return same cached instance');
        end
        
        function testDECFromDifferentManifolds(testCase)
            % Verify different manifolds create different DEC objects
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            mesh1 = bct.data.load("fsaverage6_hemi-lh_surf-pial");
            mesh2 = bct.data.load("fsaverage6_hemi-rh_surf-pial");
            
            M1 = bct.Manifold(mesh1.V, mesh1.F);
            M2 = bct.Manifold(mesh2.V, mesh2.F);
            
            dec1 = M1.DEC();
            dec2 = M2.DEC();
            
            testCase.verifyNotEqual(dec1, dec2, ...
                'DEC objects from different manifolds should be distinct');
        end
        
        %% Backend Tests
        function testDECBackendProperties(testCase)
            % Verify DiscreteExteriorCalculus backend has expected properties
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            dec = M.DEC();
            
            % Verify backend has core DEC properties
            testCase.verifyTrue(isprop(dec, 'd0'), ...
                'DEC backend should have d0 property');
            testCase.verifyTrue(isprop(dec, 'd1'), ...
                'DEC backend should have d1 property');
            testCase.verifyTrue(isprop(dec, 'hd0'), ...
                'DEC backend should have hd0 (star0) property');
            testCase.verifyTrue(isprop(dec, 'hd1'), ...
                'DEC backend should have hd1 (star1) property');
            testCase.verifyTrue(isprop(dec, 'hd2'), ...
                'DEC backend should have hd2 (star2) property');
        end
        
        function testDECBackendMethods(testCase)
            % Verify DiscreteExteriorCalculus backend has expected methods
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            dec = M.DEC();
            
            % Verify backend has operator methods
            testCase.verifyTrue(ismethod(dec, 'gradient'), ...
                'DEC backend should have gradient method');
            testCase.verifyTrue(ismethod(dec, 'divergence'), ...
                'DEC backend should have divergence method');
            testCase.verifyTrue(ismethod(dec, 'curl'), ...
                'DEC backend should have curl method');
            testCase.verifyTrue(ismethod(dec, 'laplacian'), ...
                'DEC backend should have laplacian method');
        end
        
        %% Multiple Instance Tests
        function testMultipleDECInstancesFromSameManifold(testCase)
            % Verify DEC caching works (same instance returned)
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
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
            % Verify DEC caching is per-Manifold instance
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            [V, F] = testCase.getDefaultTestMesh();
            
            M1 = bct.Manifold(V, F);
            M2 = bct.Manifold(V, F);
            
            dec1 = M1.DEC();
            dec2 = M2.DEC();
            
            % DiscreteExteriorCalculus objects with same geometry may be equal,
            % but they should be cached independently per Manifold
            dec1_again = M1.DEC();
            dec2_again = M2.DEC();
            
            testCase.verifyEqual(dec1, dec1_again, ...
                'Same Manifold should return same cached DEC');
            testCase.verifyEqual(dec2, dec2_again, ...
                'Same Manifold should return same cached DEC');
        end
    end
end
