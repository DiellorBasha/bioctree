classdef test_bct_manifold_conversion < BaseBctTest
    %TEST_BCT_MANIFOLD_CONVERSION Unit tests for bct.manifold conversion functions
    %
    % Tests bidirectional conversion between bct.Manifold and MATLAB geometry objects:
    %   - bct.manifold.in: Geometry object → Manifold
    %   - bct.manifold.out: Manifold → Geometry object
    %   - bct.manifold.load: Universal loader (file/struct/geometry → Manifold)
    %   - bct.manifold.convert: Universal converter (any → any)
    %
    % Supported geometry types:
    %   - surfaceMesh
    %   - triangulation
    %   - Patch graphics object
    %
    % See also: bct.manifold.in, bct.manifold.out, bct.manifold.load,
    %           bct.manifold.convert, BaseBctTest
    
    methods(Test)
        % =================================================================
        % bct.manifold.in Tests
        % =================================================================
        
        function testManifoldInFromSurfaceMesh(testCase)
            % Test conversion from surfaceMesh object
            mesh = bct.data.load();
            
            % Create surfaceMesh object
            smesh = surfaceMesh(mesh.V, mesh.F);
            
            % Convert to Manifold
            M = bct.manifold.in(smesh);
            
            % Verify conversion
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
            testCase.verifyEqual(size(M.Vertices), size(mesh.V));
            testCase.verifyEqual(size(M.Faces), size(mesh.F));
        end
        
        function testManifoldInFromTriangulation(testCase)
            % Test conversion from triangulation object
            mesh = bct.data.load();
            
            % Create triangulation object (requires double for Faces)
            tri = triangulation(double(mesh.F), mesh.V);
            
            % Convert to Manifold
            M = bct.manifold.in(tri);
            
            % Verify conversion
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
            testCase.verifyEqual(size(M.Vertices), size(mesh.V));
        end
        
        function testManifoldInFromPatch(testCase)
            % Test conversion from Patch graphics object
            mesh = bct.data.load();
            
            % Create invisible figure and patch object
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            
            % Create patch (requires double for Faces)
            p = patch('Faces', double(mesh.F), 'Vertices', mesh.V);
            
            % Convert to Manifold
            M = bct.manifold.in(p);
            
            % Verify conversion
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        
        function testManifoldInWithUnsupportedType(testCase)
            % Test that unsupported types are rejected
            
            % Try with a numeric array (not a geometry object)
            testCase.verifyError(@() bct.manifold.in([1, 2, 3]), ...
                'bct:manifold:UnsupportedType');
        end
        
        % =================================================================
        % bct.manifold.load Tests
        % =================================================================
        
        function testManifoldLoadFromStruct(testCase)
            % Test loading from struct with V and F fields
            mesh = bct.data.load();
            
            % Create struct
            meshStruct = struct('V', mesh.V, 'F', mesh.F);
            
            % Load via bct.manifold.load
            M = bct.manifold.load(meshStruct);
            
            % Verify
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromStructWithVerticesFacesFields(testCase)
            % Test loading from struct with Vertices and Faces fields
            mesh = bct.data.load();
            
            % Create struct with full names
            meshStruct = struct('Vertices', mesh.V, 'Faces', mesh.F);
            
            % Load via bct.manifold.load
            M = bct.manifold.load(meshStruct);
            
            % Verify
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromSurfaceMesh(testCase)
            % Test loading from surfaceMesh object via load function
            mesh = bct.data.load();
            
            % Create surfaceMesh
            smesh = surfaceMesh(mesh.V, mesh.F);
            
            % Load via bct.manifold.load (delegates to bct.manifold.in)
            M = bct.manifold.load(smesh);
            
            % Verify
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromTriangulation(testCase)
            % Test loading from triangulation object via load function
            mesh = bct.data.load();
            
            % Create triangulation (requires double for Faces)
            tri = triangulation(double(mesh.F), mesh.V);
            
            % Load via bct.manifold.load (delegates to bct.manifold.in)
            M = bct.manifold.load(tri);
            
            % Verify
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromPatch(testCase)
            % Test loading from Patch graphics object via load function
            mesh = bct.data.load();
            
            % Create invisible figure and patch
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            
            % Create patch (requires double for Faces)
            p = patch('Faces', double(mesh.F), 'Vertices', mesh.V);
            
            % Load via bct.manifold.load (delegates to bct.manifold.in)
            M = bct.manifold.load(p);
            
            % Verify
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromFile(testCase)
            % Test loading from file path
            
            % Use a known test mesh file path
            testMeshPath = 'data/mesh/fsaverage_lh_pial.mat';
            
            % Load via bct.manifold.load with file path
            M = bct.manifold.load(testMeshPath);
            
            % Verify it created a valid Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(M.numVertices(), 0);
            testCase.verifyGreaterThan(M.numFaces(), 0);
        end
        
        function testManifoldLoadWithInvalidFile(testCase)
            % Test that loading from non-existent file errors
            
            testCase.verifyError(...
                @() bct.manifold.load('nonexistent_file.mat'), ...
                'bct:manifold:FileNotFound');
        end
        
        % =================================================================
        % Data Integrity Tests
        % =================================================================
        
        function testConversionPreservesGeometry(testCase)
            % Test that all conversion paths preserve geometry data
            mesh = bct.data.load();
            
            % Create different object types
            smesh = surfaceMesh(mesh.V, mesh.F);
            tri = triangulation(double(mesh.F), mesh.V);
            
            % Convert via different paths
            M1 = bct.manifold.in(smesh);
            M2 = bct.manifold.in(tri);
            M3 = bct.manifold.load(mesh);
            
            % All should produce identical vertex counts
            testCase.verifyEqual(M1.numVertices(), M2.numVertices());
            testCase.verifyEqual(M2.numVertices(), M3.numVertices());
            
            % All should produce identical face counts
            testCase.verifyEqual(M1.numFaces(), M2.numFaces());
            testCase.verifyEqual(M2.numFaces(), M3.numFaces());
        end
        
        function testMultipleConversionsCreateIndependentObjects(testCase)
            % Test that multiple conversions create independent Manifold objects
            mesh = bct.data.load();
            
            smesh = surfaceMesh(mesh.V, mesh.F);
            
            % Create two Manifold objects from same source
            M1 = bct.manifold.in(smesh);
            M2 = bct.manifold.in(smesh);
            
            % They should have different IDs (independent objects)
            testCase.verifyNotEqual(M1.ID, M2.ID);
        end
        
        % =================================================================
        % bct.manifold.out Tests
        % =================================================================
        
        function testManifoldOutToSurfaceMesh(testCase)
            % Test Manifold → surfaceMesh conversion
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            % Convert to surfaceMesh
            smesh = bct.manifold.out(M, 'surfaceMesh');
            
            % Verify
            testCase.verifyClass(smesh, 'surfaceMesh');
            testCase.verifyEqual(size(smesh.Vertices), size(mesh.V));
            testCase.verifyEqual(size(smesh.Faces), size(mesh.F));
        end
        
        function testManifoldOutToTriangulation(testCase)
            % Test Manifold → triangulation conversion
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            % Convert to triangulation
            tri = bct.manifold.out(M, 'triangulation');
            
            % Verify
            testCase.verifyClass(tri, 'triangulation');
            testCase.verifyEqual(size(tri.Points), size(mesh.V));
            testCase.verifyEqual(size(tri.ConnectivityList), size(mesh.F));
        end
        
        function testManifoldOutToPatch(testCase)
            % Test Manifold → Patch conversion
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            % Convert to Patch
            p = bct.manifold.out(M, 'patch');
            cleanup = onCleanup(@() cleanupPatch(p));
            
            % Verify
            testCase.verifyClass(p, 'matlab.graphics.primitive.Patch');
            testCase.verifyEqual(size(p.Vertices), size(mesh.V));
            testCase.verifyEqual(size(p.Faces), size(mesh.F));
            
            % Verify faces are double
            testCase.verifyClass(p.Faces, 'double');
        end
        
        function testManifoldOutFacesConvertedToDouble(testCase)
            % Test that Faces are converted to double for triangulation and Patch
            % Note: surfaceMesh internally converts to int32
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            % surfaceMesh (MATLAB converts to int32 internally)
            smesh = bct.manifold.out(M, 'surfaceMesh');
            testCase.verifyTrue(isnumeric(smesh.Faces), ...
                'surfaceMesh Faces should be numeric');
            
            % triangulation (requires double)
            tri = bct.manifold.out(M, 'triangulation');
            testCase.verifyClass(tri.ConnectivityList, 'double');
            
            % Patch (requires double)
            p = bct.manifold.out(M, 'patch');
            cleanup = onCleanup(@() cleanupPatch(p));
            testCase.verifyClass(p.Faces, 'double');
        end
        
        % =================================================================
        % bct.manifold.convert Tests
        % =================================================================
        
        function testConvertManifoldToSurfaceMesh(testCase)
            % Test Manifold → surfaceMesh via convert
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            smesh = bct.manifold.convert(M, 'surfaceMesh');
            
            testCase.verifyClass(smesh, 'surfaceMesh');
            testCase.verifyEqual(size(smesh.Vertices, 1), M.numVertices());
        end
        
        function testConvertSurfaceMeshToManifold(testCase)
            % Test surfaceMesh → Manifold via convert
            mesh = bct.data.load();
            smesh = surfaceMesh(mesh.V, mesh.F);
            
            M = bct.manifold.convert(smesh, 'Manifold');
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
        end
        
        function testConvertGeometryToGeometry(testCase)
            % Test direct geometry → geometry conversion (via Manifold intermediary)
            mesh = bct.data.load();
            smesh = surfaceMesh(mesh.V, mesh.F);
            
            % surfaceMesh → triangulation
            tri = bct.manifold.convert(smesh, 'triangulation');
            
            testCase.verifyClass(tri, 'triangulation');
            testCase.verifyEqual(size(tri.Points, 1), size(mesh.V, 1));
            testCase.verifyEqual(size(tri.ConnectivityList, 1), size(mesh.F, 1));
        end
        
        function testConvertRoundTrip(testCase)
            % Test round-trip conversion preserves geometry
            mesh = bct.data.load();
            M_original = bct.Manifold(mesh.V, mesh.F);
            
            % Manifold → surfaceMesh → Manifold
            smesh = bct.manifold.convert(M_original, 'surfaceMesh');
            M_recovered = bct.manifold.convert(smesh, 'Manifold');
            
            % Verify geometry preserved (vertex and face counts)
            testCase.verifyEqual(M_recovered.numVertices(), M_original.numVertices());
            testCase.verifyEqual(M_recovered.numFaces(), M_original.numFaces());
        end
        
        function testConvertManifoldToManifold(testCase)
            % Test that converting Manifold to "Manifold" returns same object
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            M_same = bct.manifold.convert(M, 'Manifold');
            
            % Should be the same object (same ID)
            testCase.verifyEqual(M_same.ID, M.ID);
        end
        
        function testConvertWithInvalidTarget(testCase)
            % Test that invalid target types error appropriately
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            % Numeric target should error
            testCase.verifyError(...
                @() bct.manifold.convert(M, 123), ...
                'bct:manifold:InvalidTarget');
        end
        
        % =================================================================
        % Integration Tests: Full Pipeline
        % =================================================================
        
        function testFullConversionPipeline(testCase)
            % Test complete conversion pipeline: file → Manifold → geometry objects
            mesh = bct.data.load();
            
            % Load from default mesh
            M = bct.manifold.load(mesh);
            
            % Convert to all geometry types
            smesh = bct.manifold.out(M, 'surfaceMesh');
            tri = bct.manifold.out(M, 'triangulation');
            p = bct.manifold.out(M, 'patch');
            cleanup = onCleanup(@() cleanupPatch(p));
            
            % Verify all have same dimensions
            testCase.verifyEqual(size(smesh.Vertices, 1), M.numVertices());
            testCase.verifyEqual(size(tri.Points, 1), M.numVertices());
            testCase.verifyEqual(size(p.Vertices, 1), M.numVertices());
            
            testCase.verifyEqual(size(smesh.Faces, 1), M.numFaces());
            testCase.verifyEqual(size(tri.ConnectivityList, 1), M.numFaces());
            testCase.verifyEqual(size(p.Faces, 1), M.numFaces());
        end
        
        function testBidirectionalConversionPreservesGeometry(testCase)
            % Test that bidirectional conversions preserve geometry
            mesh = bct.data.load();
            
            % Original Manifold
            M1 = bct.Manifold(mesh.V, mesh.F);
            
            % Manifold → surfaceMesh → Manifold
            smesh = bct.manifold.out(M1, 'surfaceMesh');
            M2 = bct.manifold.in(smesh);
            
            % Manifold → triangulation → Manifold
            tri = bct.manifold.out(M1, 'triangulation');
            M3 = bct.manifold.in(tri);
            
            % All should have same geometry
            testCase.verifyEqual(M1.numVertices(), M2.numVertices());
            testCase.verifyEqual(M1.numVertices(), M3.numVertices());
            testCase.verifyEqual(M1.numFaces(), M2.numFaces());
            testCase.verifyEqual(M1.numFaces(), M3.numFaces());
        end
    end
end

% Helper function for cleanup
function cleanupPatch(p)
    % Clean up patch and its figure
    try
        if isfield(p.UserData, 'Figure') && isvalid(p.UserData.Figure)
            close(p.UserData.Figure);
        end
    catch
        % Ignore errors during cleanup
    end
end
