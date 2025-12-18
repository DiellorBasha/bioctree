%TEST_COLORMAP_SYSTEM  Comprehensive test of bct.color colormap system
%
%   Tests:
%   - ColormapRegistry singleton and initialization
%   - ColormapDefinition struct/name-value construction
%   - colormapTable registration
%   - Colormap generation via bct.color.scalar/diverging/cyclic
%   - Vector RGB mapping via bct.color.vector_hsv
%   - Registry lookup and sampling
%   - Category filtering

function test_colormap_system()
    fprintf('\n=== BCT Colormap System Test ===\n\n');
    
    try
        % Test 1: Registry initialization
        fprintf('[1/9] Testing ColormapRegistry initialization...\n');
        reg = bct.color.ColormapRegistry.instance();
        assert(~isempty(reg), 'Registry should not be empty');
        fprintf('      ✓ Registry initialized\n');
        
        % Test 2: List all colormaps
        fprintf('[2/9] Testing colormap listing...\n');
        allNames = reg.list();
        fprintf('      Found %d registered colormaps\n', numel(allNames));
        assert(numel(allNames) >= 10, 'Should have at least 10 colormaps');
        fprintf('      ✓ List operation successful\n');
        
        % Test 3: Category-based listing
        fprintf('[3/9] Testing category filtering...\n');
        byCategory = reg.listByCategory();
        fprintf('      Scalar: %d\n', numel(byCategory.Scalar));
        fprintf('      Diverging: %d\n', numel(byCategory.Diverging));
        fprintf('      Cyclic: %d\n', numel(byCategory.Cyclic));
        fprintf('      Binary: %d\n', numel(byCategory.Binary));
        fprintf('      Categorical: %d\n', numel(byCategory.Categorical));
        assert(numel(byCategory.Scalar) >= 5, 'Should have scalar colormaps');
        assert(numel(byCategory.Diverging) >= 1, 'Should have diverging colormaps');
        fprintf('      ✓ Category filtering works\n');
        
        % Test 4: Registry lookup and dimensionality
        fprintf('[4/11] Testing registry lookup...\n');
        def = reg.get('viridis');
        assert(isa(def, 'bct.color.ColormapDefinition'), 'Should return ColormapDefinition');
        assert(def.Name == "viridis", 'Name should match');
        assert(def.Category == bct.color.enum.ColormapCategory.Scalar, 'Should be Scalar category');
        assert(def.dimensionality() == 1, 'Scalar colormaps should be 1D');
        
        % Check 2D colormap
        def_2d = reg.get('vectorHSV');
        assert(def_2d.dimensionality() == 2, 'Vector colormaps should be 2D');
        assert(size(def_2d.Domain, 1) == 2, 'Vector Domain should be 2x2');
        fprintf('      ✓ Lookup successful (1D and 2D)\n');
        
        % Test 5: Colormap sampling
        fprintf('[5/11] Testing colormap sampling...\n');
        C = def.sample(256);
        assert(size(C,1) == 256 && size(C,2) == 3, 'Should be 256x3 matrix');
        assert(all(C(:) >= 0) && all(C(:) <= 1), 'Values should be in [0,1]');
        fprintf('      ✓ Sampling produces valid RGB matrix\n');
        
        % Test 6: Scalar colormap generation
        fprintf('[6/11] Testing bct.color.scalar()...\n');
        C_scalar = bct.color.scalar(0, 128);  % Grayscale
        assert(size(C_scalar,1) == 128 && size(C_scalar,2) == 3, 'Should be 128x3');
        assert(all(C_scalar(1,:) == [0 0 0]), 'Should start at black');
        assert(all(C_scalar(end,:) == [1 1 1]), 'Should end at white');
        fprintf('      ✓ Scalar generation works\n');
        
        % Test 7: Diverging colormap generation
        fprintf('[7/11] Testing bct.color.diverging()...\n');
        C_div = bct.color.diverging(1, 256);
        assert(size(C_div,1) == 256 && size(C_div,2) == 3, 'Should be 256x3');
        mid = ceil(256/2);
        % Center should be light (near white for diverging through white)
        centerBrightness = mean(C_div(mid,:));
        assert(centerBrightness > 0.7, sprintf('Center should be bright (got %.2f)', centerBrightness));
        fprintf('      ✓ Diverging generation works (center: %.2f)\n', centerBrightness);
        
        % Test 8: Cyclic colormap generation
        fprintf('[8/11] Testing bct.color.cyclic()...\n');
        C_cyc = bct.color.cyclic(360);
        assert(size(C_cyc,1) == 360 && size(C_cyc,2) == 3, 'Should be 360x3');
        % Check periodicity approximation
        dist = norm(C_cyc(1,:) - C_cyc(end,:));
        assert(dist < 0.1, 'Cyclic should be approximately periodic');
        fprintf('      ✓ Cyclic generation works\n');
        
        % Test 9: Test vector_hsv mapping
        fprintf('[9/11] Testing bct.color.vector_hsv()...\n');
        amp = [0 0.5 1; 0.3 0.7 0.9];
        phs = [-pi 0 pi; -pi/2 pi/2 3*pi/4];
        RGB_vec = bct.color.vector_hsv(amp, phs);
        assert(isequal(size(RGB_vec), [2 3 3]), 'Output should be 2x3x3 (rows x cols x RGB)');
        assert(all(RGB_vec(:) >= 0) && all(RGB_vec(:) <= 1), 'RGB values must be in [0,1]');
        fprintf('      ✓ Vector HSV mapping works\n');
        
        % Test 10: Vector HSV with options
        fprintf('[10/11] Testing vector_hsv with options...\n');
        RGB_custom = bct.color.vector_hsv(amp, phs, ...
            'maxAmplitude', 1.5, 'saturation', 0.8);
        assert(isequal(size(RGB_custom), size(RGB_vec)), 'Custom options should preserve size');
        fprintf('      ✓ Vector HSV options work\n');
        
        % Test 11: Test all registered colormaps
        fprintf('[11/11] Testing all registered colormaps...\n');
        failed = {};
        for i = 1:numel(allNames)
            try
                def_test = reg.get(allNames{i});
                C_test = def_test.sample(64);
                assert(size(C_test,2) == 3, 'Must have 3 columns (RGB)');
                assert(all(C_test(:) >= 0) && all(C_test(:) <= 1), 'Values must be in [0,1]');
            catch ME
                failed{end+1} = sprintf('%s: %s', allNames{i}, ME.message); %#ok<AGROW>
            end
        end
        
        if isempty(failed)
            fprintf('      ✓ All %d colormaps generate valid output\n', numel(allNames));
        else
            fprintf('      ✗ %d/%d colormaps failed:\n', numel(failed), numel(allNames));
            for i = 1:numel(failed)
                fprintf('        - %s\n', failed{i});
            end
            error('Some colormaps failed validation');
        end
        
        % Success summary
        fprintf('\n=== ALL TESTS PASSED ===\n');
        fprintf('Registered colormaps:\n');
        for i = 1:numel(allNames)
            fprintf('  • %s\n', allNames{i});
        end
        fprintf('\n');
        
    catch ME
        fprintf('\n✗ TEST FAILED: %s\n', ME.message);
        fprintf('Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        rethrow(ME);
    end
end
