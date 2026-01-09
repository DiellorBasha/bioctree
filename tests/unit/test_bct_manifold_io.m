classdef test_bct_manifold_io < BaseBctTest
    % TEST_BCT_MANIFOLD_IO Unit tests for bct.manifold file I/O functions
    %
    % Tests bct.manifold.read and bct.manifold.write functions using
    % test data from toolbox/+bct/+data/assets/fsaverage6/
    %
    % Test Coverage:
    %   - bct.manifold.read: Load mesh files into Manifold objects
    %   - bct.manifold.write: Write Manifold objects to mesh files
    %   - Round-trip preservation for all supported formats
    %   - Error handling for invalid inputs
    
    properties (TestParameter)
        % Test formats with corresponding file paths
        format = {'mat', 'stl', 'ply', 'obj', 'glb', 'gltf'};
    end
    
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
            testCase.TempDir = fullfile(tempdir, 'bct_manifold_io_tests');
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
        %% bct.manifold.read Tests
        
        function testReadMAT(testCase)
            % Test reading .mat file
            filePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            
            % Read file
            M = bct.manifold.read(filePath);
            
            % Verify result is Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            
            % Verify geometry is loaded
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
            testCase.verifyEqual(size(M.Vertices, 2), 3);
            testCase.verifyEqual(size(M.Faces, 2), 3);
        end
        
        function testReadSTL(testCase)
            % Test reading .stl file
            filePath = fullfile(testCase.TestDataRoot, 'stl', 'fsaverage6_hemi-lh_surf-pial.stl');
            
            % Read file
            M = bct.manifold.read(filePath);
            
            % Verify result is Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadPLY(testCase)
            % Test reading .ply file
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            
            % Read file
            M = bct.manifold.read(filePath);
            
            % Verify result is Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadOBJ(testCase)
            % Test reading .obj file
            filePath = fullfile(testCase.TestDataRoot, 'obj', 'fsaverage6_hemi-lh_surf-pial.obj');
            
            % Read file
            M = bct.manifold.read(filePath);
            
            % Verify result is Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadGLB(testCase)
            % Test reading .glb file
            filePath = fullfile(testCase.TestDataRoot, 'glb', 'fsaverage6_hemi-lh_surf-pial.glb');
            
            % Read file
            M = bct.manifold.read(filePath);
            
            % Verify result is Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadGLTF(testCase)
            % Test reading .gltf file
            filePath = fullfile(testCase.TestDataRoot, 'gltf', 'fsaverage6_hemi-lh_surf-pial.gltf');
            
            % Read file
            M = bct.manifold.read(filePath);
            
            % Verify result is Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
            testCase.verifyGreaterThan(size(M.Faces, 1), 0);
        end
        
        function testReadRightHemisphere(testCase)
            % Test reading right hemisphere mesh
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-rh_surf-pial.ply');
            
            % Read file
            M = bct.manifold.read(filePath);
            
            % Verify result
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
        end
        
        function testReadNonexistentFile(testCase)
            % Test error handling for nonexistent file
            filePath = fullfile(testCase.TempDir, 'nonexistent.ply');
            
            % Verify error is thrown
            testCase.verifyError(@() bct.manifold.read(filePath), 'bct:manifold:FileNotFound');
        end
        
        function testReadUnsupportedFormat(testCase)
            % Test error handling for unsupported format
            
            % Create a dummy file with unsupported extension
            filePath = fullfile(testCase.TempDir, 'test.xyz');
            fid = fopen(filePath, 'w');
            fwrite(fid, 'dummy data');
            fclose(fid);
            
            % Verify error is thrown
            testCase.verifyError(@() bct.manifold.read(filePath), 'bct:manifold:UnsupportedFormat');
        end
        
        %% bct.manifold.write Tests
        
        function testWriteMAT(testCase)
            % Test writing .mat file
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            % Write to new file
            outputPath = fullfile(testCase.TempDir, 'test_output.mat');
            bct.manifold.write(M, outputPath);
            
            % Verify file was created
            testCase.verifyTrue(isfile(outputPath));
            
            % Read back and verify geometry
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices), size(M.Vertices));
            testCase.verifyEqual(size(M2.Faces), size(M.Faces));
        end
        
        function testWriteSTL(testCase)
            % Test writing .stl file
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            % Write to new file
            outputPath = fullfile(testCase.TempDir, 'test_output.stl');
            bct.manifold.write(M, outputPath);
            
            % Verify file was created
            testCase.verifyTrue(isfile(outputPath));
            
            % Read back and verify geometry dimensions
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testWritePLY(testCase)
            % Test writing .ply file
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            % Write to new file
            outputPath = fullfile(testCase.TempDir, 'test_output.ply');
            bct.manifold.write(M, outputPath);
            
            % Verify file was created
            testCase.verifyTrue(isfile(outputPath));
            
            % Read back and verify geometry dimensions
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testWriteOBJ(testCase)
            % Test writing .obj file
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            % Write to new file
            outputPath = fullfile(testCase.TempDir, 'test_output.obj');
            bct.manifold.write(M, outputPath);
            
            % Verify file was created
            testCase.verifyTrue(isfile(outputPath));
            
            % Read back and verify geometry dimensions
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testWriteSTLBinaryEncoding(testCase)
            % Test writing .stl file with binary encoding
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            % Write to new file with binary encoding
            outputPath = fullfile(testCase.TempDir, 'test_output_binary.stl');
            bct.manifold.write(M, outputPath, 'Encoding', 'binary');
            
            % Verify file was created
            testCase.verifyTrue(isfile(outputPath));
            
            % Read back and verify geometry
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
        end
        
        function testWriteSTLASCIIEncoding(testCase)
            % Test writing .stl file with ASCII encoding
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            % Write to new file with ASCII encoding
            outputPath = fullfile(testCase.TempDir, 'test_output_ascii.stl');
            bct.manifold.write(M, outputPath, 'Encoding', 'ascii');
            
            % Verify file was created
            testCase.verifyTrue(isfile(outputPath));
            
            % Read back and verify geometry
            M2 = bct.manifold.read(outputPath);
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
        end
        
        function testWriteUnsupportedFormat(testCase)
            % Test error handling for unsupported format
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M = bct.manifold.read(sourcePath);
            
            % Attempt to write with unsupported extension
            outputPath = fullfile(testCase.TempDir, 'test.xyz');
            testCase.verifyError(@() bct.manifold.write(M, outputPath), 'bct:manifold:UnsupportedFormat');
        end
        
        %% Round-trip Tests
        
        function testRoundTripMAT(testCase)
            % Test MAT format round-trip preservation
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            % Write and read back
            outputPath = fullfile(testCase.TempDir, 'roundtrip.mat');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            % Verify exact preservation for MAT format
            testCase.verifyEqual(M2.Vertices, M1.Vertices, 'AbsTol', 1e-10);
            testCase.verifyEqual(M2.Faces, M1.Faces);
        end
        
        function testRoundTripSTL(testCase)
            % Test STL format round-trip
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            % Write and read back
            outputPath = fullfile(testCase.TempDir, 'roundtrip.stl');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            % Verify dimensions preserved (STL may not preserve exact vertex order)
            testCase.verifyEqual(size(M2.Vertices, 1), size(M1.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M1.Faces, 1));
        end
        
        function testRoundTripPLY(testCase)
            % Test PLY format round-trip
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            % Write and read back
            outputPath = fullfile(testCase.TempDir, 'roundtrip.ply');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            % Verify dimensions preserved
            testCase.verifyEqual(size(M2.Vertices, 1), size(M1.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M1.Faces, 1));
        end
        
        function testRoundTripOBJ(testCase)
            % Test OBJ format round-trip
            
            % Load source mesh
            sourcePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(sourcePath);
            
            % Write and read back
            outputPath = fullfile(testCase.TempDir, 'roundtrip.obj');
            bct.manifold.write(M1, outputPath);
            M2 = bct.manifold.read(outputPath);
            
            % Verify dimensions preserved
            testCase.verifyEqual(size(M2.Vertices, 1), size(M1.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M1.Faces, 1));
        end
        
        %% Cross-format Tests
        
        function testCrossFormatConversion(testCase)
            % Test converting between different formats
            
            % Load PLY file
            plyPath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            M = bct.manifold.read(plyPath);
            
            % Write as STL
            stlPath = fullfile(testCase.TempDir, 'converted.stl');
            bct.manifold.write(M, stlPath);
            
            % Read back STL
            M2 = bct.manifold.read(stlPath);
            
            % Verify geometry dimensions preserved
            testCase.verifyEqual(size(M2.Vertices, 1), size(M.Vertices, 1));
            testCase.verifyEqual(size(M2.Faces, 1), size(M.Faces, 1));
        end
        
        function testMultiFormatWorkflow(testCase)
            % Test realistic workflow with multiple format conversions
            
            % Start with MAT file
            matPath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            M1 = bct.manifold.read(matPath);
            originalVertexCount = size(M1.Vertices, 1);
            originalFaceCount = size(M1.Faces, 1);
            
            % Convert to STL
            stlPath = fullfile(testCase.TempDir, 'workflow.stl');
            bct.manifold.write(M1, stlPath);
            M2 = bct.manifold.read(stlPath);
            testCase.verifyEqual(size(M2.Vertices, 1), originalVertexCount);
            
            % Convert to PLY
            plyPath = fullfile(testCase.TempDir, 'workflow.ply');
            bct.manifold.write(M2, plyPath);
            M3 = bct.manifold.read(plyPath);
            testCase.verifyEqual(size(M3.Vertices, 1), originalVertexCount);
            
            % Convert to OBJ
            objPath = fullfile(testCase.TempDir, 'workflow.obj');
            bct.manifold.write(M3, objPath);
            M4 = bct.manifold.read(objPath);
            testCase.verifyEqual(size(M4.Vertices, 1), originalVertexCount);
            
            % Final check: all formats preserved vertex/face count
            testCase.verifyEqual(size(M4.Faces, 1), originalFaceCount);
        end
        
        %% Integration with bct.manifold.load Tests
        
        function testLoadFromFilePath(testCase)
            % Test bct.manifold.load with MAT file path
            
            filePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            
            % Load using bct.manifold.load (works with MAT files)
            M = bct.manifold.load(filePath);
            
            % Verify result is Manifold
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
        end
        
        function testLoadFromStruct(testCase)
            % Test bct.manifold.load with struct
            
            % Load file first
            filePath = fullfile(testCase.TestDataRoot, 'surf', 'fsaverage6_hemi-lh_surf-pial.mat');
            data = load(filePath);
            
            % Load from struct
            M = bct.manifold.load(data);
            
            % Verify result
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0);
        end
        
        %% Integration with bct.manifold.convert Tests
        
        function testConvertToGeometryAfterRead(testCase)
            % Test converting read Manifold to geometry objects
            
            % Read mesh file
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            M = bct.manifold.read(filePath);
            
            % Convert to surfaceMesh
            sm = bct.manifold.convert(M, 'surfaceMesh');
            testCase.verifyClass(sm, 'surfaceMesh');
            testCase.verifyEqual(size(sm.Vertices, 1), size(M.Vertices, 1));
            
            % Convert to triangulation
            tr = bct.manifold.convert(M, 'triangulation');
            testCase.verifyClass(tr, 'triangulation');
            testCase.verifyEqual(size(tr.Points, 1), size(M.Vertices, 1));
        end
        
        function testConvertGeometryAndWrite(testCase)
            % Test workflow: geometry → Manifold → write → read → geometry
            
            % Start with surfaceMesh from file
            filePath = fullfile(testCase.TestDataRoot, 'ply', 'fsaverage6_hemi-lh_surf-pial.ply');
            sm1 = readSurfaceMesh(filePath);
            
            % Convert to Manifold
            M = bct.manifold.convert(sm1, 'Manifold');
            
            % Write to file
            outputPath = fullfile(testCase.TempDir, 'converted_workflow.obj');
            bct.manifold.write(M, outputPath);
            
            % Read back
            M2 = bct.manifold.read(outputPath);
            
            % Convert back to surfaceMesh
            sm2 = bct.manifold.convert(M2, 'surfaceMesh');
            
            % Verify dimensions preserved
            testCase.verifyEqual(size(sm2.Vertices, 1), size(sm1.Vertices, 1));
            testCase.verifyEqual(size(sm2.Faces, 1), size(sm1.Faces, 1));
        end
    end
end
