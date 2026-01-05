classdef test_bct_brush < BaseBctTest
    % TEST_BCT_BRUSH Unit tests for bct.brush registry/runtime system
    %
    % Tests brush system integration:
    % - bct.registry.brushes (authoritative definitions)
    % - bct.runtime.brushes (context-aware dispatch)
    % - Backward compatibility with bct.brush.apply()
    % - Cache management
    %
    % See: notes/BrushContract.md, notes/BRUSH_INTEGRATION_PLAN.md
    
    methods (Test)
        %% Registry Interface Tests
        function testRegistryGetAllBrushes(testCase)
            % Verify registry returns all brush definitions
            defs = bct.registry.brushes();
            
            testCase.verifyNotEmpty(defs, ...
                'Registry should contain brush definitions');
            testCase.verifyClass(defs, 'struct', ...
                'Registry should return struct array');
            testCase.verifyGreaterThanOrEqual(numel(defs), 8, ...
                'Registry should contain at least 8 brushes');
        end
        
        function testRegistryGetSpecificBrush(testCase)
            % Verify registry can retrieve specific brush by ID
            spec = bct.registry.brushes('get', 'patch_gaussian');
            
            testCase.verifyNotEmpty(spec, ...
                'Should retrieve patch_gaussian spec');
            testCase.verifyEqual(spec.Id, 'patch_gaussian', ...
                'Spec ID should match requested ID');
            testCase.verifyTrue(isfield(spec, 'Evaluate'), ...
                'Spec should have Evaluate function');
        end
        
        function testRegistryValidateBrushSpec(testCase)
            % Verify registry can validate brush spec
            spec = bct.registry.brushes('get', 'patch_gaussian');
            [ok, msg] = bct.registry.brushes('validate', spec);
            
            testCase.verifyTrue(ok, ...
                sprintf('Validation should pass: %s', msg));
        end
        
        function testRegistryListBrushes(testCase)
            % Verify registry can list all brush IDs
            ids = bct.registry.brushes('list');
            
            testCase.verifyNotEmpty(ids, ...
                'List should return brush IDs');
            testCase.verifyClass(ids, 'string', ...
                'IDs should be string array');
            testCase.verifyTrue(any(strcmp(ids, 'patch_gaussian')), ...
                'List should include patch_gaussian');
        end
        
        function testRegistrySchema(testCase)
            % Verify registry provides schema
            schema = bct.registry.brushes('schema');
            
            testCase.verifyTrue(isfield(schema, 'RequiredFields'), ...
                'Schema should have RequiredFields');
            testCase.verifyTrue(isfield(schema, 'AllowedValues'), ...
                'Schema should have AllowedValues');
        end
        
        %% Runtime Interface Tests
        function testRuntimeDictionary(testCase)
            % Verify runtime returns filtered dictionary for manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            dict = bct.runtime.brushes('dictionary', M);
            
            testCase.verifyNotEmpty(dict, ...
                'Runtime dictionary should contain compatible brushes');
            testCase.verifyClass(dict, 'struct', ...
                'Dictionary should be struct array');
        end
        
        function testRuntimeResolve(testCase)
            % Verify runtime resolves brush with context
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            context = struct(...
                'manifold', M, ...
                'params', struct('center', 1000, 'radius', 15));
            resolvedSpec = bct.runtime.brushes('resolve', 'patch_gaussian', context);
            
            testCase.verifyNotEmpty(resolvedSpec, ...
                'Runtime should resolve brush spec');
            testCase.verifyTrue(isfield(resolvedSpec, 'DefaultParamsResolved'), ...
                'Resolved spec should have DefaultParamsResolved');
        end
        
        function testRuntimeListAvailableBrushes(testCase)
            % Verify runtime lists brushes compatible with manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            availableIds = bct.runtime.brushes('list', M);
            
            testCase.verifyNotEmpty(availableIds, ...
                'Runtime should list available brushes');
            testCase.verifyClass(availableIds, 'string', ...
                'Available IDs should be string array');
        end
        
        function testRuntimeCacheClear(testCase)
            % Verify runtime cache can be cleared
            cleared = bct.runtime.brushes('clear');
            
            testCase.verifyTrue(cleared, ...
                'Cache clear should return true');
        end
        
        %% Backward Compatibility Tests
        function testApplyPatchGaussian(testCase)
            % Test patch_gaussian via backward-compatible apply()
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            params = struct('center', 1000, 'radius', 20);
            w = bct.brush.apply('patch_gaussian', M, params);
            
            testCase.verifyNotEmpty(w, ...
                'patch_gaussian should produce output');
            testCase.verifyEqual(size(w, 1), M.numVertices, ...
                'Output should have N vertices');
            testCase.verifyClass(w, 'double', ...
                'Output should be double');
        end
        
        function testApplyPatchSpectral(testCase)
            % Test patch_spectral via apply() (requires eigenpairs)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            params = struct('center', 5000, 'numModes', 100, 'bandwidth', 0.05);
            w = bct.brush.apply('patch_spectral', M, params);
            
            testCase.verifyNotEmpty(w, ...
                'patch_spectral should produce output');
            testCase.verifyEqual(size(w, 1), M.numVertices, ...
                'Output should have N vertices');
        end
        
        function testApplyPatchNearest(testCase)
            % Test patch_nearest via apply()
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            params = struct('center', 1000, 'k', 100);
            w = bct.brush.apply('patch_nearest', M, params);
            
            testCase.verifyNotEmpty(w, ...
                'patch_nearest should produce output');
            testCase.verifyEqual(size(w, 1), M.numVertices, ...
                'Output should have N vertices');
        end
        
        %% Direct Evaluation Tests
        function testDirectEvaluationWithDefaults(testCase)
            % Test direct evaluation using default parameters
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            spec = bct.registry.brushes('get', 'patch_nearest');
            defaultParams = spec.DefaultParams(M);
            
            testCase.verifyTrue(isfield(defaultParams, 'center'), ...
                'Default params should have center field');
            testCase.verifyTrue(isfield(defaultParams, 'k'), ...
                'Default params should have k field');
            
            w = spec.Evaluate(M, defaultParams);
            
            testCase.verifyEqual(size(w, 1), M.numVertices, ...
                'Direct evaluation should produce correct size output');
        end
        
        function testDirectEvaluationWithCustomParams(testCase)
            % Test direct evaluation with custom parameters
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            spec = bct.registry.brushes('get', 'patch_gaussian');
            params = struct('center', 2000, 'radius', 25);
            w = spec.Evaluate(M, params);
            
            testCase.verifyNotEmpty(w, ...
                'Direct evaluation with custom params should work');
        end
        
        %% Cache Management Tests
        function testCacheRebuild(testCase)
            % Verify cache can be cleared and rebuilt
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Build cache
            dict1 = bct.runtime.brushes('dictionary', M);
            
            % Clear cache
            bct.runtime.brushes('clear');
            
            % Rebuild cache
            dict2 = bct.runtime.brushes('dictionary', M);
            
            testCase.verifyEqual(numel(dict1), numel(dict2), ...
                'Cache rebuild should produce same number of entries');
        end
        
        %% Integration Tests
        function testMultipleBrushesSequentially(testCase)
            % Test applying multiple brushes in sequence
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Apply three different brushes
            w1 = bct.brush.apply('patch_nearest', M, struct('center', 1000, 'k', 50));
            w2 = bct.brush.apply('patch_gaussian', M, struct('center', 2000, 'radius', 15));
            w3 = bct.brush.apply('patch_spectral', M, struct('center', 3000, 'numModes', 80, 'bandwidth', 0.03));
            
            testCase.verifyEqual(size(w1, 1), M.numVertices, ...
                'First brush should produce correct output size');
            testCase.verifyEqual(size(w2, 1), M.numVertices, ...
                'Second brush should produce correct output size');
            testCase.verifyEqual(size(w3, 1), M.numVertices, ...
                'Third brush should produce correct output size');
        end
        
        function testBrushCategories(testCase)
            % Verify brushes are properly categorized
            [~, categories] = bct.registry.brushes('list');
            
            % Check that we have different categories
            uniqueCategories = unique(categories);
            testCase.verifyGreaterThanOrEqual(numel(uniqueCategories), 3, ...
                'Should have at least 3 brush categories');
            
            % Verify specific categories exist
            testCase.verifyTrue(any(strcmp(categories, 'patch')), ...
                'Should have patch category brushes');
            testCase.verifyTrue(any(strcmp(categories, 'trajectory')), ...
                'Should have trajectory category brushes');
            testCase.verifyTrue(any(strcmp(categories, 'time')), ...
                'Should have time category brushes');
        end
        
        %% Error Handling Tests
        function testUnknownBrushError(testCase)
            % Verify error on unknown brush ID
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            testCase.verifyError(@() bct.brush.apply('nonexistent_brush', M, struct()), ...
                '?*', 'Should error on unknown brush');
        end
        
        function testInvalidBrushIdInRegistry(testCase)
            % Verify error when getting invalid brush from registry
            testCase.verifyError(@() bct.registry.brushes('get', 'invalid_brush_id'), ...
                '?*', 'Registry should error on invalid brush ID');
        end
    end
end
