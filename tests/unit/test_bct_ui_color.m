classdef test_bct_ui_color < BaseBctTest
    % TEST_BCT_UI_COLOR  Unit tests for bct.ui.color package
    %
    % Tests the color mapping system including:
    %   - bct.registry.colormaps (metadata)
    %   - bct.runtime.colormap (execution layer)
    %   - bct.ui.color.* functions (UI API)
    %
    % See also: BaseBctTest, BCTUICOLOR_CONTRACT.md
    
    methods (Test)
        %% Registry Tests
        
        function testRegistryColormapsExists(testCase)
            % Test that registry function exists and returns struct array
            defs = bct.registry.colormaps();
            
            testCase.verifyTrue(isstruct(defs));
            testCase.verifyGreaterThan(numel(defs), 0);
        end
        
        function testRegistryHasRequiredFields(testCase)
            % Test that registry entries have required fields
            defs = bct.registry.colormaps();
            
            requiredFields = ["Id", "Provider", "Kind", "DefaultN"];
            for f = requiredFields
                testCase.verifyTrue(isfield(defs, f), ...
                    sprintf('Missing required field: %s', f));
            end
        end
        
        function testRegistryHasMatlabAndBct(testCase)
            % Test that registry includes both MATLAB and BCT colormaps
            defs = bct.registry.colormaps();
            providers = string({defs.Provider});
            
            testCase.verifyTrue(any(providers == "matlab"));
            testCase.verifyTrue(any(providers == "bct"));
        end
        
        function testRegistryHasParulaTurboRedblue(testCase)
            % Test that specific expected colormaps are present
            defs = bct.registry.colormaps();
            ids = string({defs.Id});
            
            testCase.verifyTrue(any(ids == "parula"));
            testCase.verifyTrue(any(ids == "turbo"));
            testCase.verifyTrue(any(ids == "redblue"));
        end
        
        function testRegistryIdsUnique(testCase)
            % Test that colormap IDs are unique
            defs = bct.registry.colormaps();
            ids = string({defs.Id});
            
            testCase.verifyEqual(numel(ids), numel(unique(ids)), ...
                'Colormap IDs must be unique');
        end
        
        %% Runtime Dictionary Tests
        
        function testRuntimeDictionaryExists(testCase)
            % Test that runtime dictionary can be created
            D = bct.runtime.colormap();
            
            testCase.verifyClass(D, 'dictionary');
            testCase.verifyGreaterThan(numEntries(D), 0);
        end
        
        function testRuntimeDictionaryHasParula(testCase)
            % Test that parula is in dictionary
            D = bct.runtime.colormap();
            
            testCase.verifyTrue(isKey(D, "parula"));
        end
        
        function testRuntimeDictionaryHasRedblue(testCase)
            % Test that redblue is in dictionary
            D = bct.runtime.colormap();
            
            testCase.verifyTrue(isKey(D, "redblue"));
        end
        
        function testRuntimeGeneratorCallable(testCase)
            % Test that generators can be called
            D = bct.runtime.colormap();
            
            gen = D("parula");
            cmap = gen(256);
            
            testCase.verifySize(cmap, [256 3]);
            testCase.verifyClass(cmap, 'double');
        end
        
        %% bct.ui.color.schema Tests
        
        function testSchemaReturnsStruct(testCase)
            % Test schema returns struct with required fields
            spec = bct.ui.color.schema();
            
            testCase.verifyClass(spec, 'struct');
            testCase.verifyTrue(isfield(spec, 'Colormap'));
            testCase.verifyTrue(isfield(spec, 'NColors'));
            testCase.verifyTrue(isfield(spec, 'CLim'));
            testCase.verifyTrue(isfield(spec, 'NaNColor'));
        end
        
        function testSchemaDefaults(testCase)
            % Test schema default values
            spec = bct.ui.color.schema();
            
            testCase.verifyEqual(string(spec.Colormap), "parula");
            testCase.verifyEqual(spec.NColors, 256);
            testCase.verifyEmpty(spec.CLim);
            testCase.verifySize(spec.NaNColor, [1 3]);
        end
        
        %% bct.ui.color.list Tests
        
        function testListReturnsStringArray(testCase)
            % Test list returns string array
            ids = bct.ui.color.list();
            
            testCase.verifyClass(ids, 'string');
            testCase.verifyGreaterThan(numel(ids), 0);
        end
        
        function testListIncludesExpectedColormaps(testCase)
            % Test list includes expected colormaps
            ids = bct.ui.color.list();
            
            testCase.verifyTrue(any(ids == "parula"));
            testCase.verifyTrue(any(ids == "turbo"));
            testCase.verifyTrue(any(ids == "redblue"));
        end
        
        %% bct.ui.color.resolve Tests
        
        function testResolveParula(testCase)
            % Test resolving parula colormap
            cmap = bct.ui.color.resolve("parula", 256);
            
            testCase.verifySize(cmap, [256 3]);
            testCase.verifyClass(cmap, 'double');
            testCase.verifyGreaterThanOrEqual(min(cmap(:)), 0);
            testCase.verifyLessThanOrEqual(max(cmap(:)), 1);
        end
        
        function testResolveRedblue(testCase)
            % Test resolving custom redblue colormap
            cmap = bct.ui.color.resolve("redblue", 256);
            
            testCase.verifySize(cmap, [256 3]);
            testCase.verifyClass(cmap, 'double');
            testCase.verifyGreaterThanOrEqual(min(cmap(:)), 0);
            testCase.verifyLessThanOrEqual(max(cmap(:)), 1);
        end
        
        function testResolveCustomSize(testCase)
            % Test resolving with custom number of colors
            cmap = bct.ui.color.resolve("turbo", 128);
            
            testCase.verifySize(cmap, [128 3]);
        end
        
        function testResolveUnknownColormapThrowsError(testCase)
            % Test that unknown colormap throws correct error
            testCase.verifyError(...
                @() bct.ui.color.resolve("nonexistent", 256), ...
                'bct:ui:color:UnknownColormap');
        end
        
        %% bct.ui.color.clim Tests
        
        function testClimFromData(testCase)
            % Test CLim computation from data
            data = [1 2 3 4 5];
            limits = bct.ui.color.clim(data);
            
            testCase.verifySize(limits, [1 2]);
            testCase.verifyEqual(limits, [1 5]);
        end
        
        function testClimWithNaN(testCase)
            % Test CLim ignores NaN values
            data = [1 2 NaN 3 4];
            limits = bct.ui.color.clim(data);
            
            testCase.verifyEqual(limits, [1 4]);
        end
        
        function testClimWithInf(testCase)
            % Test CLim ignores Inf values
            data = [1 2 Inf 3 4];
            limits = bct.ui.color.clim(data);
            
            testCase.verifyEqual(limits, [1 4]);
        end
        
        function testClimAllNaN(testCase)
            % Test CLim with all NaN returns default
            data = [NaN NaN NaN];
            limits = bct.ui.color.clim(data);
            
            testCase.verifyEqual(limits, [0 1]);
        end
        
        function testClimConstant(testCase)
            % Test CLim with constant data
            data = [5 5 5 5];
            limits = bct.ui.color.clim(data);
            
            testCase.verifyEqual(limits, [5 5]);
        end
        
        %% bct.ui.color.validate Tests
        
        function testValidateValidSpec(testCase)
            % Test validate accepts valid spec
            spec = bct.ui.color.schema();
            
            % Should not throw
            bct.ui.color.validate(spec);
        end
        
        function testValidateInvalidColormap(testCase)
            % Test validate rejects invalid Colormap
            spec = bct.ui.color.schema();
            spec.Colormap = 123;  % Not a string
            
            testCase.verifyError(...
                @() bct.ui.color.validate(spec), ...
                'bct:ui:color:InvalidColormap');
        end
        
        function testValidateInvalidNColors(testCase)
            % Test validate rejects invalid NColors
            spec = bct.ui.color.schema();
            spec.NColors = -5;
            
            testCase.verifyError(...
                @() bct.ui.color.validate(spec), ...
                'bct:ui:color:InvalidNColors');
        end
        
        function testValidateInvalidNaNColor(testCase)
            % Test validate rejects invalid NaNColor
            spec = bct.ui.color.schema();
            spec.NaNColor = [0.5 0.5];  % Wrong size
            
            testCase.verifyError(...
                @() bct.ui.color.validate(spec), ...
                'bct:ui:color:InvalidNaNColor');
        end
        
        function testValidateInvalidCLim(testCase)
            % Test validate rejects invalid CLim
            spec = bct.ui.color.schema();
            spec.CLim = [5 2];  % Lo > Hi
            
            testCase.verifyError(...
                @() bct.ui.color.validate(spec), ...
                'bct:ui:color:InvalidCLim');
        end
        
        %% bct.ui.color.rgb Tests
        
        function testRgbBasicUsage(testCase)
            % Test basic RGB mapping
            data = [1 2 3 4 5];
            rgb = bct.ui.color.rgb(data);
            
            testCase.verifySize(rgb, [1 5 3]);
            testCase.verifyClass(rgb, 'double');
        end
        
        function testRgbWith2DData(testCase)
            % Test RGB mapping with 2D data
            data = randn(10, 20);
            rgb = bct.ui.color.rgb(data);
            
            testCase.verifySize(rgb, [10 20 3]);
        end
        
        function testRgbWithColormap(testCase)
            % Test RGB with custom colormap
            data = [1 2 3];
            rgb = bct.ui.color.rgb(data, "Colormap", "turbo");
            
            testCase.verifySize(rgb, [1 3 3]);
        end
        
        function testRgbWithCLim(testCase)
            % Test RGB with explicit CLim
            data = [1 2 3 4 5];
            rgb = bct.ui.color.rgb(data, "CLim", [0 10]);
            
            testCase.verifySize(rgb, [1 5 3]);
        end
        
        function testRgbNaNMapping(testCase)
            % Test that NaN values map to NaNColor
            data = [1 NaN 3];
            nanColor = [1 0 0];  % Red
            rgb = bct.ui.color.rgb(data, "NaNColor", nanColor);
            
            % Check that middle value is red
            testCase.verifyEqual(squeeze(rgb(1, 2, :))', nanColor, 'AbsTol', 1e-10);
        end
        
        function testRgbConstantField(testCase)
            % Test RGB with constant field (should not error)
            data = [5 5 5 5];
            rgb = bct.ui.color.rgb(data);
            
            testCase.verifySize(rgb, [1 4 3]);
            % All values should map to same color
            testCase.verifyEqual(rgb(1,1,:), rgb(1,2,:));
        end
        
        function testRgbOptionalOutput(testCase)
            % Test RGB with optional output struct
            data = [1 2 3];
            [rgb, out] = bct.ui.color.rgb(data);
            
            testCase.verifyClass(out, 'struct');
            testCase.verifyTrue(isfield(out, 'ColormapId'));
            testCase.verifyTrue(isfield(out, 'Colormap'));
            testCase.verifyTrue(isfield(out, 'CLim'));
            testCase.verifyTrue(isfield(out, 'ValidMask'));
        end
        
        function testRgbRedblueColormap(testCase)
            % Test RGB with BCT custom colormap
            data = linspace(-1, 1, 100);
            rgb = bct.ui.color.rgb(data, "Colormap", "redblue");
            
            testCase.verifySize(rgb, [1 100 3]);
            
            % Check that negative values are bluish, positive are reddish
            % (first value should be blue, last should be red)
            blueColor = squeeze(rgb(1, 1, :));
            redColor = squeeze(rgb(1, end, :));
            
            % Blue should have highest blue component
            [~, blueMaxIdx] = max(blueColor);
            testCase.verifyEqual(blueMaxIdx, 3);  % B channel
            
            % Red should have highest red component
            [~, redMaxIdx] = max(redColor);
            testCase.verifyEqual(redMaxIdx, 1);  % R channel
        end
        
        %% Integration Tests
        
        function testEndToEndWorkflow(testCase)
            % Test complete workflow from data to RGB
            
            % Create test data
            [X, Y] = meshgrid(linspace(-2, 2, 50), linspace(-2, 2, 50));
            data = sin(X) .* cos(Y);
            
            % Map to RGB
            [rgb, out] = bct.ui.color.rgb(data, ...
                "Colormap", "redblue", ...
                "NColors", 256);
            
            % Verify output
            testCase.verifySize(rgb, [50 50 3]);
            testCase.verifyEqual(out.ColormapId, "redblue");
            testCase.verifySize(out.Colormap, [256 3]);
            testCase.verifySize(out.ValidMask, [50 50]);
            testCase.verifyTrue(all(out.ValidMask(:)));  % All finite
        end
        
        function testDiscoveryWorkflow(testCase)
            % Test UI discovery workflow
            
            % Get list of available colormaps
            ids = bct.ui.color.list();
            
            % User selects one (simulate)
            selectedId = ids(1);
            
            % Use it for mapping
            data = randn(10, 10);
            rgb = bct.ui.color.rgb(data, "Colormap", selectedId);
            
            testCase.verifySize(rgb, [10 10 3]);
        end
    end
end
