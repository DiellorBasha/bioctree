function tests = test_manifold_health
    % test_manifold_health - Unit tests for bct.manifold.health module
    %
    % Tests health checking capabilities for mesh and Manifold validation:
    %   - Topology checks (manifoldness, degeneracy, indices)
    %   - Orientation checks (consistency, outward direction)
    %   - Check orchestration (quick, standard, full levels)
    %   - Report generation
    %
    % Usage:
    %   result = runtests('test_manifold_health');
    %
    % Coverage:
    %   - bct.manifold.health.check
    %   - bct.manifold.health.topology
    %   - bct.manifold.health.orientation
    %   - bct.manifold.health.report
    %
    % Total: 23 tests
    
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Apply shared fixture that initializes BCT and loads default mesh
    testCase.TestData.fixture = testCase.applyFixture(ManifoldFixture());
end

%% ========================================================================
%% TOPOLOGY TESTS
%% ========================================================================

function testTopologyValidMesh(testCase)
    % Test: bct.manifold.health.topology on valid manifold
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Check topology (should pass)
    R = bct.manifold.health.topology(M);
    
    % Verify report structure
    verifyClass(testCase, R, 'struct');
    verifyTrue(testCase, isfield(R, 'ok'));
    verifyTrue(testCase, isfield(R, 'severity'));
    verifyTrue(testCase, isfield(R, 'issues'));
    verifyTrue(testCase, isfield(R, 'stats'));
    
    % Valid manifold should pass
    verifyTrue(testCase, R.ok, 'Valid manifold should pass topology check');
    verifyEqual(testCase, R.severity, "ok");
    
    % Check stats
    verifyTrue(testCase, R.stats.nV > 0);
    verifyTrue(testCase, R.stats.nF > 0);
    verifyTrue(testCase, R.stats.nE > 0);
    verifyEqual(testCase, R.stats.nNonManifoldEdges, 0, ...
        'Valid manifold should have no non-manifold edges');
end

function testTopologyDegenerateFaces(testCase)
    % Test: topology check detects degenerate faces
    
    % Create mesh with degenerate face (repeated vertex)
    V = [0 0 0; 1 0 0; 0 1 0; 1 1 0];
    F = [1 2 3; 1 1 2];  % Second face has repeated vertex 1
    
    % Check topology (should fail)
    R = bct.manifold.health.topology({V, F}, 'RequireManifold', false);
    
    % Should detect degenerate faces
    verifyFalse(testCase, R.ok, 'Degenerate faces should fail check');
    verifyGreaterThanOrEqual(testCase, length(R.issues), 1);
    
    % Check that degenerate_faces_repeated_vertices issue is reported
    issueIds = [R.issues.id];
    verifyTrue(testCase, any(issueIds == "degenerate_faces_repeated_vertices"));
end

function testTopologyInvalidIndices(testCase)
    % Test: topology check detects invalid indices
    
    % Create mesh with out-of-range index
    V = [0 0 0; 1 0 0; 0 1 0];
    F = [1 2 3; 1 2 5];  % Second face references non-existent vertex 5
    
    % Check topology (should fail)
    R = bct.manifold.health.topology({V, F}, 'RequireManifold', false);
    
    % Should detect invalid indices
    verifyFalse(testCase, R.ok, 'Invalid indices should fail check');
    
    % Check for invalid_faces_indices issue
    issueIds = [R.issues.id];
    verifyTrue(testCase, any(issueIds == "invalid_faces_indices"));
end

function testTopologyNonManifoldEdge(testCase)
    % Test: topology check detects non-manifold edges
    
    % Create mesh with non-manifold edge (edge shared by 3 faces)
    V = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
    F = [1 2 3; 1 2 4; 1 2 3];  % Edge (1,2) shared by 3 faces
    
    % Check topology with RequireManifold=false (to get report)
    R = bct.manifold.health.topology({V, F}, 'RequireManifold', false);
    
    % Should detect non-manifold edges
    verifyFalse(testCase, R.ok, 'Non-manifold edges should fail check');
    verifyGreaterThan(testCase, R.stats.nNonManifoldEdges, 0);
end

function testTopologyBoundaryEdges(testCase)
    % Test: topology check detects boundary edges
    
    % Create open mesh (single triangle)
    V = [0 0 0; 1 0 0; 0 1 0];
    F = [1 2 3];
    
    % Check with RequireClosed=false (should pass)
    R = bct.manifold.health.topology({V, F}, ...
        'RequireManifold', false, 'RequireClosed', false);
    verifyTrue(testCase, R.ok, 'Open mesh should pass when RequireClosed=false');
    verifyEqual(testCase, R.stats.nBoundaryEdges, 3, ...
        'Triangle should have 3 boundary edges');
    
    % Check with RequireClosed=true (should fail)
    R = bct.manifold.health.topology({V, F}, ...
        'RequireManifold', false, 'RequireClosed', true);
    verifyFalse(testCase, R.ok, 'Open mesh should fail when RequireClosed=true');
end

%% ========================================================================
%% ORIENTATION TESTS
%% ========================================================================

function testOrientationConsistent(testCase)
    % Test: orientation check on consistently oriented mesh
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Check orientation (should be consistent)
    R = bct.manifold.health.orientation(M);
    
    % Verify report structure
    verifyClass(testCase, R, 'struct');
    verifyTrue(testCase, R.ok, 'Valid manifold should have consistent orientation');
    
    % Check stats
    verifyTrue(testCase, isfield(R.stats, 'nInteriorEdges'));
    verifyEqual(testCase, R.stats.nInconsistentInteriorEdges, 0, ...
        'Valid manifold should have no inconsistent edges');
end

function testOrientationInconsistent(testCase)
    % Test: orientation check detects inconsistent orientation
    
    % Create mesh with inconsistent orientation
    % Two faces sharing edge (1,2), both traversing it 1→2 (same direction = inconsistent)
    % Face 1: [1, 2, 3] has edges: 1→2, 2→3, 3→1
    % Face 2: [4, 1, 2] has edges: 4→1, 1→2, 2→4  (edge 1→2 same direction as Face 1!)
    V = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
    F = [1 2 3; 4 1 2];  % Both traverse edge (1,2) as 1→2 (inconsistent!)
    
    % Check orientation with RequireConsistent=true (should fail)
    R = bct.manifold.health.orientation({V, F}, 'RequireConsistent', true);
    
    % Should detect inconsistent orientation
    verifyFalse(testCase, R.ok, 'Inconsistent orientation should fail check');
    verifyGreaterThan(testCase, R.stats.nInconsistentInteriorEdges, 0);
end

function testOrientationOutward(testCase)
    % Test: orientation check verifies outward-facing normals
    
    % Create simple tetrahedron with known orientation
    V = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
    F = [1 3 2; 1 2 4; 2 3 4; 3 1 4];  % Outward-facing
    
    % Check orientation with outward test
    R = bct.manifold.health.orientation({V, F}, 'CheckOutward', true);
    
    % Verify outward status is computed
    verifyTrue(testCase, isfield(R.stats, 'outwardStatus'));
    verifyTrue(testCase, isfield(R.stats, 'signedVolume'));
end

%% ========================================================================
%% CHECK ORCHESTRATION TESTS
%% ========================================================================

function testCheckQuickLevel(testCase)
    % Test: bct.manifold.health.check with quick level
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Quick check (topology only)
    R = bct.manifold.health.check(M, 'Level', "quick");
    
    % Verify report structure
    verifyClass(testCase, R, 'struct');
    verifyTrue(testCase, R.ok);
    verifyEqual(testCase, R.level, "quick");
    verifyTrue(testCase, isfield(R, 'timing'));
end

function testCheckStandardLevel(testCase)
    % Test: bct.manifold.health.check with standard level
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Standard check (topology + orientation + boundary + geometry)
    R = bct.manifold.health.check(M, 'Level', "standard");
    
    % Verify report structure
    verifyClass(testCase, R, 'struct');
    verifyTrue(testCase, R.ok);
    verifyEqual(testCase, R.level, "standard");
    
    % Standard should include more checks than quick
    verifyTrue(testCase, isfield(R, 'summary'));
end

function testCheckWithManifold(testCase)
    % Test: check accepts bct.Manifold directly
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Check with Manifold object
    R = bct.manifold.health.check(M);
    
    verifyTrue(testCase, R.ok);
    verifyEqual(testCase, R.stats.nV, size(M.Vertices, 1));
    verifyEqual(testCase, R.stats.nF, size(M.Faces, 1));
end

function testCheckWithVF(testCase)
    % Test: check accepts {V, F} cell array
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Check with {V, F}
    R = bct.manifold.health.check({M.Vertices, M.Faces});
    
    verifyTrue(testCase, R.ok);
    verifyEqual(testCase, R.stats.nV, size(M.Vertices, 1));
    verifyEqual(testCase, R.stats.nF, size(M.Faces, 1));
end

function testCheckWithFacesOnly(testCase)
    % Test: check accepts F alone (topology checks only)
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Check with F only
    R = bct.manifold.health.check(M.Faces);
    
    % Should still perform topology checks
    verifyClass(testCase, R, 'struct');
    verifyTrue(testCase, isfield(R, 'ok'));
end

function testCheckCustomChecks(testCase)
    % Test: check with custom Checks parameter
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Run only topology check
    R = bct.manifold.health.check(M, 'Checks', ["topology"]);
    
    verifyClass(testCase, R, 'struct');
    verifyTrue(testCase, R.ok);
end

function testCheckRequirements(testCase)
    % Test: check requirement flags
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Check with requirements
    R = bct.manifold.health.check(M, ...
        'RequireManifold', true, ...
        'RequireOriented', true, ...
        'RequireClosed', false);
    
    % Valid manifold should pass all requirements
    verifyTrue(testCase, R.ok);
end

%% ========================================================================
%% REPORT GENERATION TESTS
%% ========================================================================

function testReportGeneration(testCase)
    % Test: bct.manifold.health.report generates formatted text
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Get health check result
    R = bct.manifold.health.check(M);
    
    % Generate report (without printing)
    txt = bct.manifold.health.report(R, 'Print', false);
    
    % Verify report is generated
    verifyClass(testCase, txt, 'string');
    verifyGreaterThan(testCase, strlength(txt), 0, ...
        'Report should contain text');
    
    % Report should contain key information
    verifyTrue(testCase, contains(txt, "HEALTH CHECK", 'IgnoreCase', true));
    verifyTrue(testCase, contains(txt, R.severity, 'IgnoreCase', true));
end

function testReportCompactMode(testCase)
    % Test: report compact mode
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    R = bct.manifold.health.check(M);
    
    % Generate compact report
    txt = bct.manifold.health.report(R, 'Print', false, 'Compact', true);
    
    % Compact report should be shorter but still contain info
    verifyClass(testCase, txt, 'string');
    verifyGreaterThan(testCase, strlength(txt), 0);
end

function testReportWithIssues(testCase)
    % Test: report displays issues
    
    % Create mesh with known issues
    V = [0 0 0; 1 0 0; 0 1 0];
    F = [1 2 3; 1 1 2];  % Degenerate face
    
    R = bct.manifold.health.check({V, F}, 'RequireManifold', false);
    
    % Generate report
    txt = bct.manifold.health.report(R, 'Print', false);
    
    % Report should mention issues
    verifyTrue(testCase, contains(txt, "issue", 'IgnoreCase', true) || ...
                         contains(txt, "error", 'IgnoreCase', true) || ...
                         contains(txt, "problem", 'IgnoreCase', true));
end

%% ========================================================================
%% INPUT VALIDATION TESTS
%% ========================================================================

function testInputManifoldObject(testCase)
    % Test: all functions accept bct.Manifold object
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % All functions should accept Manifold
    R1 = bct.manifold.health.topology(M);
    verifyClass(testCase, R1, 'struct');
    
    R2 = bct.manifold.health.orientation(M);
    verifyClass(testCase, R2, 'struct');
    
    R3 = bct.manifold.health.check(M);
    verifyClass(testCase, R3, 'struct');
end

function testInputCellArray(testCase)
    % Test: functions accept {V, F} cell array
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    R = bct.manifold.health.topology({M.Vertices, M.Faces});
    verifyClass(testCase, R, 'struct');
end

function testInputFacesOnly(testCase)
    % Test: topology checks work with F alone
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    R = bct.manifold.health.topology(M.Faces);
    verifyClass(testCase, R, 'struct');
    
    % Should have stats but may not have all geometric checks
    verifyTrue(testCase, isfield(R.stats, 'nF'));
end

%% ========================================================================
%% EDGE CASES
%% ========================================================================

function testEmptyMesh(testCase)
    % Test: health check handles empty mesh gracefully
    
    V = zeros(0, 3);
    F = zeros(0, 3);
    
    % Should handle empty mesh without error
    R = bct.manifold.health.topology({V, F}, 'RequireManifold', false);
    
    verifyClass(testCase, R, 'struct');
    verifyEqual(testCase, R.stats.nF, 0);
end

function testSingleTriangle(testCase)
    % Test: health check handles minimal valid mesh
    
    V = [0 0 0; 1 0 0; 0 1 0];
    F = [1 2 3];
    
    R = bct.manifold.health.check({V, F}, ...
        'RequireClosed', false, 'RequireManifold', false);
    
    % Single triangle is topologically valid (but open)
    verifyClass(testCase, R, 'struct');
    verifyEqual(testCase, R.stats.nF, 1);
    verifyEqual(testCase, R.stats.nBoundaryEdges, 3);
end
