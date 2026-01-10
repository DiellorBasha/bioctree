classdef test_bct_manifold_pkg < BaseBctTest
    %TEST_BCT_MANIFOLD_PKG Unit tests for bct.manifold package
    %
    % Tests the bct.manifold package functions for:
    %   - File I/O: read and write mesh files (MAT, STL, PLY, OBJ, GLB, GLTF)
    %   - Conversion: bidirectional conversion between Manifold and geometry objects
    %   - Loading: universal loader supporting multiple input types
    %
    % Supported geometry types:
    %   - surfaceMesh
    %   - triangulation
    %   - Patch graphics object
    %
    % Note: This tests the bct.manifold PACKAGE functions (read, write, in, out, 
    %       load, convert). The bct.Manifold CLASS is tested in test_bct_Manifold.m
    %
    % See also: bct.manifold.read, bct.manifold.write, bct.manifold.in,
    %           bct.manifold.out, bct.manifold.load, bct.manifold.convert,
    %           BaseBctTest, test_bct_Manifold
    
    properties
        TestDataRoot
        TempDir
    end
    
    methods (TestClassSetup)
        function setupTestData(testCase)
            % Locate test data directory using BaseBctTest.getBctRoot()
            bctRoot = testCase.getBctRoot();
            testCase.TestDataRoot = fullfile(bctRoot, 'toolbox', '+bct', '+data', 'assets', 'fsaverage6');
            
            % Verify test data exists
            if ~exist(testCase.TestDataRoot, 'dir')
                error('bct:test:TestDataNotFound', 'Test data directory not found: %s', testCase.TestDataRoot);
            end
            
            % Create temporary directory for write tests
            testCase.TempDir = fullfile(tempdir, 'bct_manifold_tests');
            if ~exist(testCase.TempDir, 'dir')
                mkdir(testCase.TempDir);
            end
        end
    end
    
    methods (TestClassTeardown)
        function cleanupTempFiles(testCase)
            % Remove temporary directory
            if exist(testCase.TempDir, 'dir')
                rmdir(testCase.TempDir, 's');
            end
        end
    end
    
    methods (Test)
        % =================================================================
        % File I/O Tests: bct.manifold.read
        % =================================================================
        
        function testReadMAT(testCase)
            % Test reading .mat file
            filePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            
            M = bct.manifold.read(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
            testCase.verifyEqual(size(M.Vertices, 2), 3);
            testCase.verifyEqual(size(M.Faces, 2), 3);
        end
        
        function testReadSTL(testCase)
            % Test reading .stl file
            filePath = fullfile(testCase.TestDataRoot, 'stl', 'fsaverage6_hemi-lh_surf-pial.stl');
            
            M = bct.manifold.read(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadPLY(testCase)
            % Test reading .ply file
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            
            M = bct.manifold.read(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadOBJ(testCase)
            % Test reading .obj file
            filePath = fullfile(testCase.TestDataRoot, 'obj', 'fsaverage6_hemi-lh_surf-pial.obj');
            
            M = bct.manifold.read(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadGLB(testCase)
            % Test reading .glb file
            filePath = fullfile(testCase.TestDataRoot, 'glb', 'fsaverage6_hemi-lh_surf-pial.glb');
            
            M = bct.manifold.read(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadGLTF(testCase)
            % Test reading .gltf file
            filePath = fullfile(testCase.TestDataRoot, 'gltf', 'fsaverage6_hemi-lh_surf-pial.gltf');
            
            M = bct.manifold.read(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadRightHemisphere(testCase)
            % Test reading right hemisphere mesh
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-rh_surf-pial.ply');
            
            M = bct.manifold.read(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
        end
        
        function testReadNonexistentFile(testCase)
            % Test error handling for nonexistent file
            filePath = fullfile(testCase.TempDir, 'nonexistent.ply');
            
            testCase.verifyError(@() bct.manifold.read(filePath), 'bct:manifold:FileNotFound');
        end
        
        function testReadUnsupportedFormat(testCase)
            % Test error handling for unsupported format
            filePath = fullfile(testCase.TempDir, 'test.xyz');
            fid = fopen(filePath, 'w');
            fwrite(fid, 'dummy data');
            fclose(fid);
            
            testCase.verifyError(@() bct.manifold.read(filePath), 'bct:manifold:UnsupportedFormat');
        end
        
        % =================================================================
        % File I/O Tests: bct.manifold.write
        % =================================================================
        
        function testWriteMAT(testCase)
            % Test writing .mat file
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'test_output.mat');
            bct.manifold.write(M, outputPath);
            
            testCase.verifyTrue(isfile(outputPath));
            
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices), size(M.Vertices));
            testCase.verifyEqual(size(M2.Faces), size(M.Faces));
        end
        
        function testWriteSTL(testCase)
            % Test writing .stl file
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'test_output.stl');
            bct.manifold.write(M, outputPath);
            
            testCase.verifyTrue(isfile(outputPath));
            
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testWritePLY(testCase)
            % Test writing .ply file
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'test_output.ply');
            bct.manifold.write(M, outputPath);
            
            testCase.verifyTrue(isfile(outputPath));
            
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testWriteOBJ(testCase)
            % Test writing .obj file
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'test_output.obj');
            bct.manifold.write(M, outputPath);
            
            testCase.verifyTrue(isfile(outputPath));
            
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testWriteSTLBinaryEncoding(testCase)
            % Test writing .stl file with binary encoding
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'test_output_binary.stl');
            bct.manifold.write(M, outputPath, 'Encoding', 'binary');
            
            testCase.verifyTrue(isfile(outputPath));
            
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
        end
        
        function testWriteSTLASCIIEncoding(testCase)
            % Test writing .stl file with ASCII encoding
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'test_output_ascii.stl');
            bct.manifold.write(M, outputPath, 'Encoding', 'ascii');
            
            testCase.verifyTrue(isfile(outputPath));
            
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
        end
        
        function testWriteUnsupportedFormat(testCase)
            % Test error handling for unsupported format
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'test.xyz');
            testCase.verifyError(@() bct.manifold.write(M, outputPath), 'bct:manifold:UnsupportedFormat');
        end
        
        % =================================================================
        % Round-trip Tests
        % =================================================================
        
        function testRoundTripMAT(testCase)
            % Test MAT format round-trip preservation
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'roundtrip.mat');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            testCase.verifyEqual(M2.Vertices, M1.Vertices, 'AbsTol', 1e-10);
            testCase.verifyEqual(M2.Faces, M1.Faces);
        end
        
        function testRoundTripSTL(testCase)
            % Test STL format round-trip
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'roundtrip.stl');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            testCase.verifyEqual(size(M2.Vertices, 1), size(M1.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M1.Faces, 1));
        end
        
        function testRoundTripPLY(testCase)
            % Test PLY format round-trip
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'roundtrip.ply');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            testCase.verifyEqual(size(M2.Vertices, 1), size(M1.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M1.Faces, 1));
        end
        
        function testRoundTripOBJ(testCase)
            % Test OBJ format round-trip
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            outputPath = fullfile(testCase.TempDir, 'roundtrip.obj');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            testCase.verifyEqual(size(M2.Vertices, 1), size(M1.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M1.Faces, 1));
        end
        
        function testCrossFormatConversion(testCase)
            % Test converting between different formats
            plyPath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            M = bct.manifold.read(plyPath);
            
            stlPath = fullfile(testCase.TempDir, 'converted.stl');
            bct.manifold.write(M, stlPath);
            
            M2 = bct.manifold.read(stlPath);
            
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testMultiFormatWorkflow(testCase)
            % Test realistic workflow with multiple format conversions
            matPath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(matPath);
            originalVertexCount = size(M1.Vertices, 1);
            originalFaceCount = size(M1.Faces, 1);
            
            stlPath = fullfile(testCase.TempDir, 'workflow.stl');
            bct.manifold.write(M1, stlPath);
            M2 = bct.manifold.read(stlPath);
            testCase.verifyEqual(size(M2.Vertices, 1), originalVertexCount);
            
            plyPath = fullfile(testCase.TempDir, 'workflow.ply');
            bct.manifold.write(M2, plyPath);
            M3 = bct.manifold.read(plyPath);
            testCase.verifyEqual(size(M3.Vertices, 1), originalVertexCount);
            
            objPath = fullfile(testCase.TempDir, 'workflow.obj');
            bct.manifold.write(M3, objPath);
            M4 = bct.manifold.read(objPath);
            testCase.verifyEqual(size(M4.Vertices, 1), originalVertexCount);
            testCase.verifyEqual(size(M4.Faces, 1), originalFaceCount);
        end
        
        % =================================================================
        % Conversion Tests: bct.manifold.in (geometry → Manifold)
        % =================================================================
        
        function testManifoldInFromSurfaceMesh(testCase)
            % Test conversion from surfaceMesh object
            mesh = bct.data.load();
            
            smesh = surfaceMesh(mesh.V, mesh.F);
            M = bct.manifold.in(smesh);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
            testCase.verifyEqual(size(M.Vertices), size(mesh.V));
            testCase.verifyEqual(size(M.Faces), size(mesh.F));
        end
        
        function testManifoldInFromTriangulation(testCase)
            % Test conversion from triangulation object
            mesh = bct.data.load();
            
            tri = triangulation(double(mesh.F), mesh.V);
            M = bct.manifold.in(tri);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
            testCase.verifyEqual(size(M.Vertices), size(mesh.V));
        end
        
        function testManifoldInFromPatch(testCase)
            % Test conversion from Patch graphics object
            mesh = bct.data.load();
            
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            
            p = patch('Faces', double(mesh.F), 'Vertices', mesh.V);
            M = bct.manifold.in(p);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldInWithUnsupportedType(testCase)
            % Test that unsupported types are rejected
            testCase.verifyError(@() bct.manifold.in([1, 2, 3]), 'bct:manifold:UnsupportedType');
        end
        
        % =================================================================
        % Conversion Tests: bct.manifold.out (Manifold → geometry)
        % =================================================================
        
        function testManifoldOutToSurfaceMesh(testCase)
            % Test Manifold → surfaceMesh conversion
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            smesh = bct.manifold.out(M, 'surfaceMesh');
            
            testCase.verifyClass(smesh, 'surfaceMesh');
            testCase.verifyEqual(size(smesh.Vertices), size(mesh.V));
            testCase.verifyEqual(size(smesh.Faces), size(mesh.F));
        end
        
        function testManifoldOutToTriangulation(testCase)
            % Test Manifold → triangulation conversion
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            tri = bct.manifold.out(M, 'triangulation');
            
            testCase.verifyClass(tri, 'triangulation');
            testCase.verifyEqual(size(tri.Points), size(mesh.V));
            testCase.verifyEqual(size(tri.ConnectivityList), size(mesh.F));
        end
        
        function testManifoldOutToPatch(testCase)
            % Test Manifold → Patch conversion
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            p = bct.manifold.out(M, 'patch');
            cleanup = onCleanup(@() cleanupPatch(p));
            
            testCase.verifyClass(p, 'matlab.graphics.primitive.Patch');
            testCase.verifyEqual(size(p.Vertices), size(mesh.V));
            testCase.verifyEqual(size(p.Faces), size(mesh.F));
            testCase.verifyClass(p.Faces, 'double');
        end
        
        function testManifoldOutFacesConvertedToDouble(testCase)
            % Test that Faces are converted to double for triangulation and Patch
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            smesh = bct.manifold.out(M, 'surfaceMesh');
            testCase.verifyTrue(isnumeric(smesh.Faces), 'surfaceMesh Faces should be numeric');
            
            tri = bct.manifold.out(M, 'triangulation');
            testCase.verifyClass(tri.ConnectivityList, 'double');
            
            p = bct.manifold.out(M, 'patch');
            cleanup = onCleanup(@() cleanupPatch(p));
            testCase.verifyClass(p.Faces, 'double');
        end
        
        % =================================================================
        % Universal Loader Tests: bct.manifold.load
        % =================================================================
        
        function testManifoldLoadFromStruct(testCase)
            % Test loading from struct with V and F fields
            mesh = bct.data.load();
            
            meshStruct = struct('V', mesh.V, 'F', mesh.F);
            M = bct.manifold.load(meshStruct);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromStructWithVerticesFacesFields(testCase)
            % Test loading from struct with Vertices and Faces fields
            mesh = bct.data.load();
            
            meshStruct = struct('Vertices', mesh.V, 'Faces', mesh.F);
            M = bct.manifold.load(meshStruct);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromSurfaceMesh(testCase)
            % Test loading from surfaceMesh object via load function
            mesh = bct.data.load();
            
            smesh = surfaceMesh(mesh.V, mesh.F);
            M = bct.manifold.load(smesh);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromTriangulation(testCase)
            % Test loading from triangulation object via load function
            mesh = bct.data.load();
            
            tri = triangulation(double(mesh.F), mesh.V);
            M = bct.manifold.load(tri);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromPatch(testCase)
            % Test loading from Patch graphics object via load function
            mesh = bct.data.load();
            
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            
            p = patch('Faces', double(mesh.F), 'Vertices', mesh.V);
            M = bct.manifold.load(p);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(M.numVertices(), size(mesh.V, 1));
            testCase.verifyEqual(M.numFaces(), size(mesh.F, 1));
        end
        
        function testManifoldLoadFromFile(testCase)
            % Test loading from file path
            testMeshPath = 'data/mesh/fsaverage_lh_pial.mat';
            
            M = bct.manifold.load(testMeshPath);
            
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
        
        function testLoadFromFilePath(testCase)
            % Test bct.manifold.load with MAT file path
            filePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            
            M = bct.manifold.load(filePath);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
        end
        
        function testLoadFromStruct(testCase)
            % Test bct.manifold.load with struct
            filePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            data = load(filePath);
            
            M = bct.manifold.load(data);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
        end
        
        % =================================================================
        % Universal Converter Tests: bct.manifold.convert
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
            
            tri = bct.manifold.convert(smesh, 'triangulation');
            
            testCase.verifyClass(tri, 'triangulation');
            testCase.verifyEqual(size(tri.Points, 1), size(mesh.V, 1));
            testCase.verifyEqual(size(tri.ConnectivityList, 1), size(mesh.F, 1));
        end
        
        function testConvertRoundTrip(testCase)
            % Test round-trip conversion preserves geometry
            mesh = bct.data.load();
            M_original = bct.Manifold(mesh.V, mesh.F);
            
            smesh = bct.manifold.convert(M_original, 'surfaceMesh');
            M_recovered = bct.manifold.convert(smesh, 'Manifold');
            
            testCase.verifyEqual(M_recovered.numVertices(), M_original.numVertices());
            testCase.verifyEqual(M_recovered.numFaces(), M_original.numFaces());
        end
        
        function testConvertManifoldToManifold(testCase)
            % Test that converting Manifold to "Manifold" returns same object
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            M_same = bct.manifold.convert(M, 'Manifold');
            
            testCase.verifyEqual(M_same.ID, M.ID);
        end
        
        function testConvertWithInvalidTarget(testCase)
            % Test that invalid target types error appropriately
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            
            testCase.verifyError(...
                @() bct.manifold.convert(M, 123), ...
                'bct:manifold:InvalidTarget');
        end
        
        function testConvertToGeometryAfterRead(testCase)
            % Test converting read Manifold to geometry objects
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            M = bct.manifold.read(filePath);
            
            sm = bct.manifold.convert(M, 'surfaceMesh');
            testCase.verifyClass(sm, 'surfaceMesh');
            testCase.verifyEqual(size(sm.Vertices, 1), size(M.Vertices, 1));
            
            tr = bct.manifold.convert(M, 'triangulation');
            testCase.verifyClass(tr, 'triangulation');
            testCase.verifyEqual(size(tr.Points, 1), size(M.Vertices, 1));
        end
        
        function testConvertGeometryAndWrite(testCase)
            % Test workflow: geometry → Manifold → write → read → geometry
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            sm1 = readSurfaceMesh(filePath);
            
            M = bct.manifold.convert(sm1, 'Manifold');
            
            outputPath = fullfile(testCase.TempDir, 'converted_workflow.obj');
            bct.manifold.write(M, outputPath);
            
            M2 = bct.manifold.read(outputPath);
            
            sm2 = bct.manifold.convert(M2, 'surfaceMesh');
            
            testCase.verifyEqual(size(sm2.Vertices, 1), size(sm1.Vertices, 1));
            testCase.verifyEqual(size(sm2.Faces, 1), size(sm1.Faces, 1));
        end
        
        % =================================================================
        % Data Integrity Tests
        % =================================================================
        
        function testConversionPreservesGeometry(testCase)
            % Test that all conversion paths preserve geometry data
            mesh = bct.data.load();
            
            smesh = surfaceMesh(mesh.V, mesh.F);
            tri = triangulation(double(mesh.F), mesh.V);
            
            M1 = bct.manifold.in(smesh);
            M2 = bct.manifold.in(tri);
            M3 = bct.manifold.load(mesh);
            
            testCase.verifyEqual(M1.numVertices(), M2.numVertices());
            testCase.verifyEqual(M2.numVertices(), M3.numVertices());
            testCase.verifyEqual(M1.numFaces(), M2.numFaces());
            testCase.verifyEqual(M2.numFaces(), M3.numFaces());
        end
        
        function testMultipleConversionsCreateIndependentObjects(testCase)
            % Test that multiple conversions create independent Manifold objects
            mesh = bct.data.load();
            
            smesh = surfaceMesh(mesh.V, mesh.F);
            
            M1 = bct.manifold.in(smesh);
            M2 = bct.manifold.in(smesh);
            
            testCase.verifyNotEqual(M1.ID, M2.ID);
        end
        
        % =================================================================
        % Integration Tests: Full Pipeline
        % =================================================================
        
        function testFullConversionPipeline(testCase)
            % Test complete conversion pipeline: file → Manifold → geometry objects
            mesh = bct.data.load();
            
            M = bct.manifold.load(mesh);
            
            smesh = bct.manifold.out(M, 'surfaceMesh');
            tri = bct.manifold.out(M, 'triangulation');
            p = bct.manifold.out(M, 'patch');
            cleanup = onCleanup(@() cleanupPatch(p));
            
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
            
            M1 = bct.Manifold(mesh.V, mesh.F);
            
            smesh = bct.manifold.out(M1, 'surfaceMesh');
            M2 = bct.manifold.in(smesh);
            
            tri = bct.manifold.out(M1, 'triangulation');
            M3 = bct.manifold.in(tri);
            
            testCase.verifyEqual(M1.numVertices(), M2.numVertices());
            testCase.verifyEqual(M1.numVertices(), M3.numVertices());
            testCase.verifyEqual(M1.numFaces(), M2.numFaces());
            testCase.verifyEqual(M1.numFaces(), M3.numFaces());
        end
    end
end

% Helper function for cleanup
function cleanupPatch(p)
    try
        if isfield(p.UserData, 'Figure') && isvalid(p.UserData.Figure)
            close(p.UserData.Figure);
        end
    catch
        % Ignore errors during cleanup
    end
end
