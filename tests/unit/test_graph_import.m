classdef test_graph_import < matlab.unittest.TestCase
    % TEST_GRAPH_IMPORT Test graph-type Manifold creation from FreeSurfer import
    
    properties
        TestDataPath
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            % Add paths
            bioctree_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(bioctree_root);
            addpath(genpath(fullfile(bioctree_root, 'toolbox')));
            addpath(genpath(fullfile(bioctree_root, 'external')));
            
            % Set test data path
            testCase.TestDataPath = fullfile(bioctree_root, 'test-data', 'freesurfer', 'fsaverage', 'surf', 'lh.pial');
            
            % Verify test file exists
            if ~isfile(testCase.TestDataPath)
                error('Test data file not found: %s', testCase.TestDataPath);
            end
        end
    end
    
    methods (Test)
        function testGraphTypeCreation(testCase)
            % Test that import.graph creates a graph-type Manifold
            B = bct.io.import.graph(testCase.TestDataPath);
            
            % Verify Manifold type
            testCase.verifyEqual(B.Manifold.Type, "graph", ...
                'Expected graph type Manifold');
        end
        
        function testEdgesCreated(testCase)
            % Test that edges are properly created from faces
            B = bct.io.import.graph(testCase.TestDataPath);
            
            % Verify edges exist
            testCase.verifyGreaterThan(height(B.Manifold.Edges), 0, ...
                'Expected non-empty edges table');
            
            % Verify edges table structure
            testCase.verifyTrue(ismember('EndNodes', B.Manifold.Edges.Properties.VariableNames), ...
                'Edges table should contain EndNodes variable');
            testCase.verifyTrue(ismember('Weight', B.Manifold.Edges.Properties.VariableNames), ...
                'Edges table should contain Weight variable');
            
            % Verify EndNodes is Mx2
            testCase.verifyEqual(size(B.Manifold.Edges.EndNodes, 2), 2, ...
                'EndNodes should be Mx2 matrix');
        end
        
        function testVerticesPreserved(testCase)
            % Test that vertices are preserved for spatial embedding
            B = bct.io.import.graph(testCase.TestDataPath);
            
            % Verify vertices exist
            testCase.verifyFalse(isempty(B.Manifold.V), ...
                'Expected vertices to be preserved');
            
            % Verify vertices are Nx3
            testCase.verifyEqual(size(B.Manifold.V, 2), 3, ...
                'Vertices should be Nx3 matrix');
        end
        
        function testNMatchesVertexCount(testCase)
            % Test that N property matches number of vertices
            B = bct.io.import.graph(testCase.TestDataPath);
            
            testCase.verifyEqual(B.Manifold.N, size(B.Manifold.V, 1), ...
                'N should match vertex count');
        end
        
        function testAdjacencyMatrix(testCase)
            % Test adjacency matrix creation
            B = bct.io.import.graph(testCase.TestDataPath);
            A = B.Manifold.adjacency();
            
            % Verify sparse matrix
            testCase.verifyTrue(issparse(A), ...
                'Expected sparse adjacency matrix');
            
            % Verify size matches N
            testCase.verifyEqual(size(A, 1), B.Manifold.N, ...
                'Adjacency matrix rows should match N');
            testCase.verifyEqual(size(A, 2), B.Manifold.N, ...
                'Adjacency matrix columns should match N');
            
            % Verify symmetry
            testCase.verifyTrue(isequal(A, A'), ...
                'Adjacency matrix should be symmetric');
            
            % Verify no self-loops
            testCase.verifyEqual(nnz(diag(A)), 0, ...
                'Adjacency matrix should have no self-loops');
        end
        
        function testLaplacian(testCase)
            % Test Laplacian computation
            B = bct.io.import.graph(testCase.TestDataPath);
            L = B.Manifold.laplacian();
            
            % Verify sparse matrix
            testCase.verifyTrue(issparse(L), ...
                'Expected sparse Laplacian');
            
            % Verify size
            testCase.verifyEqual(size(L, 1), B.Manifold.N, ...
                'Laplacian size should match N');
            
            % Verify symmetry
            testCase.verifyTrue(norm(L - L', 'fro') < 1e-10, ...
                'Laplacian should be symmetric');
        end
        
        function testBackwardCompatibilityProperties(testCase)
            % Test that backward compatibility properties still work
            B = bct.io.import.graph(testCase.TestDataPath);
            
            % Test that legacy properties delegate to Manifold
            testCase.verifyEqual(B.Vertices, B.Manifold.V, ...
                'Vertices should delegate to Manifold.V');
            
            % Note: Faces will be empty for graph type, which is expected
            testCase.verifyTrue(isempty(B.Faces), ...
                'Faces should be empty for graph-type Manifold');
        end
    end
end

