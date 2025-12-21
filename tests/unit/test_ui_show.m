classdef test_ui_show < BaseBctTest
    % TEST_UI_SHOW Unit tests for bct.ui.show and inspector dispatch
    %
    % Tests:
    %   - bct.ui.show can create standalone figure for Manifold
    %   - Registry correctly routes bct.Manifold to ManifoldInspector
    %   - Inspector is properly instantiated and bound to object
    %   - Figure cleanup works correctly
    
    methods (Test)
        function testShowManifoldStandalone(testCase)
            % Test that bct.ui.show creates standalone figure for Manifold
            
            % Load test mesh
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            
            % Call bct.ui.show
            [inspector, fig] = bct.ui.show(M);
            
            % Verify figure was created
            testCase.verifyNotEmpty(fig, 'Figure should be created for standalone usage');
            testCase.verifyTrue(isvalid(fig), 'Figure should be valid');
            testCase.verifyClass(fig, 'matlab.ui.Figure', 'Should return uifigure');
            
            % Verify inspector was created
            testCase.verifyNotEmpty(inspector, 'Inspector should be created');
            testCase.verifyTrue(isvalid(inspector), 'Inspector should be valid');
            
            % Verify inspector type
            testCase.verifyClass(inspector, 'bct.ui.manifold.Inspector', ...
                'Should instantiate ManifoldInspector for bct.Manifold');
            
            % Cleanup
            delete(fig);
        end
        
        function testShowManifoldWithParent(testCase)
            % Test that bct.ui.show can embed inspector in provided parent
            
            % Create parent figure and layout
            fig = uifigure('Visible', 'off');
            gl = uigridlayout(fig, [1, 1]);
            
            % Load test mesh
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            
            % Call bct.ui.show with Parent
            [inspector, returnedFig] = bct.ui.show(M, 'Parent', gl);
            
            % Verify no new figure was created
            testCase.verifyEmpty(returnedFig, ...
                'Should not create new figure when Parent is provided');
            
            % Verify inspector was created
            testCase.verifyNotEmpty(inspector, 'Inspector should be created');
            testCase.verifyTrue(isvalid(inspector), 'Inspector should be valid');
            testCase.verifyClass(inspector, 'bct.ui.manifold.Inspector', ...
                'Should instantiate ManifoldInspector');
            
            % Verify inspector is child of provided parent
            testCase.verifyEqual(inspector.Parent, gl, ...
                'Inspector parent should be the provided grid layout');
            
            % Cleanup
            delete(fig);
        end
        
        function testRegistryDispatch(testCase)
            % Test that registry correctly dispatches to ManifoldInspector
            
            % Load test mesh
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            
            % Resolve inspector via runtime
            [factory, def] = bct.runtime.ui.resolveInspector(M);
            
            % Verify inspector definition
            testCase.verifyEqual(def.Id, "ManifoldInspector", ...
                'Should resolve to ManifoldInspector');
            testCase.verifyEqual(def.Class, "bct.ui.manifold.Inspector", ...
                'Should have correct class path');
            testCase.verifyTrue(any(def.Supports == "bct.Manifold"), ...
                'Should support bct.Manifold class');
            
            % Verify factory is a function handle
            testCase.verifyClass(factory, 'function_handle', ...
                'Factory should be a function handle');
        end
        
        function testInspectorInstantiation(testCase)
            % Test that ManifoldInspector can be instantiated directly
            
            % Create parent
            fig = uifigure('Visible', 'off');
            gl = uigridlayout(fig, [1, 1]);
            
            % Load test mesh
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            
            % Instantiate inspector directly
            inspector = bct.ui.manifold.Inspector(gl);
            
            % Verify creation
            testCase.verifyNotEmpty(inspector, 'Inspector should be created');
            testCase.verifyTrue(isvalid(inspector), 'Inspector should be valid');
            
            % Bind Manifold via adapter
            [V, F] = bct.ui.data.manifoldToMesh(M);
            inspector.Vertices = V;
            inspector.Faces = F;
            
            % Verify binding (compare values, not types since Faces might be int32 or double)
            testCase.verifyEqual(inspector.Vertices, M.Vertices, ...
                'Vertices should match Manifold');
            testCase.verifyEqual(double(inspector.Faces), double(M.Faces), ...
                'Faces should match Manifold (converted to double for comparison)');
            
            % Cleanup
            delete(fig);
        end
        
        function testShowWithTitle(testCase)
            % Test that custom title is applied to figure
            
            % Load test mesh
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            
            % Call with custom title
            customTitle = "Test Manifold Viewer";
            [~, fig] = bct.ui.show(M, 'Title', customTitle);
            
            % Verify title
            testCase.verifyEqual(string(fig.Name), customTitle, ...
                'Figure title should match provided title');
            
            % Cleanup
            delete(fig);
        end
        
        function testShowWithPosition(testCase)
            % Test that custom position is applied to figure
            
            % Load test mesh
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            
            % Call with custom position
            customPos = [100, 100, 600, 400];
            [~, fig] = bct.ui.show(M, 'Position', customPos);
            
            % Verify position
            testCase.verifyEqual(fig.Position, customPos, ...
                'Figure position should match provided position');
            
            % Cleanup
            delete(fig);
        end
        
        function testListInspectors(testCase)
            % Test that bct.ui.listInspectors returns available inspectors
            
            inspectors = bct.ui.listInspectors();
            
            % Verify we have inspectors
            testCase.verifyNotEmpty(inspectors, ...
                'Should have registered inspectors');
            
            % Verify ManifoldInspector is in the list
            ids = [inspectors.Id];
            testCase.verifyTrue(any(ids == "ManifoldInspector"), ...
                'ManifoldInspector should be in registry');
        end
        
        function testInvalidObjectClass(testCase)
            % Test that unsupported object class throws error
            
            % Create unsupported object
            unsupportedObj = struct('data', rand(10, 10));
            
            % Verify error is thrown
            testCase.verifyError(@() bct.ui.show(unsupportedObj), ...
                'bct:ui:show:ResolverFailed', ...
                'Should throw error for unsupported class');
        end
    end
end
