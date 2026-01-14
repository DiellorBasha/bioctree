function tests = test_localize
    % test_localize - Test bct.manifold.operator.localize function
    %
    % Tests localization of spectral filters to specific vertices:
    % - Heat kernel localization
    % - Multiple filter scales (filterbank)
    % - Output format options (stack vs cell)
    % - Input validation
    %
    % Total: 8 tests
    
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Apply shared fixture that initializes BCT and loads default mesh
    testCase.TestData.fixture = testCase.applyFixture(ManifoldFixture());
end

%% ========================================================================
%% HEAT KERNEL LOCALIZATION
%% ========================================================================

function testHeatLocalizationTau10Vertex1000(testCase)
    % Test: Localize heat filter with tau=10 at vertex 1000
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    E = fixture.E;  % Use precomputed eigenmodes from fixture
    
    % Design heat filter with tau=10
    F = bct.filter.design(E.values, "Heat", "tau", 10);
    
    % Localize at vertex 1000
    vertexIdx = 1000;
    localField = bct.manifold.operator.localize(M, vertexIdx, F);
    
    % Verify output structure
    verifyClass(testCase, localField, 'double');
    verifySize(testCase, localField, [M.nVertices, 1], ...
        'Localized field should be [nVertices × 1]');
    
    % Verify no NaN/Inf
    verifyTrue(testCase, all(isfinite(localField)), ...
        'Localized field should contain finite values');
    
    % Verify maximum is at or near vertex 1000
    [maxVal, maxIdx] = max(localField);
    verifyGreaterThan(testCase, maxVal, 0, 'Maximum should be positive');
    
    % The maximum should be at vertex 1000 or a nearby vertex
    % (spectral filtering can spread slightly)
    distance = abs(maxIdx - vertexIdx);
    verifyLessThanOrEqual(testCase, distance, 50, ...
        'Maximum should be near vertex 1000');
    
    % Verify decay: values should decrease with geodesic distance
    % Sample a few vertices near 1000 and further away
    nearIdx = min(vertexIdx + 100, M.nVertices);
    farIdx = min(vertexIdx + 1000, M.nVertices);
    verifyGreaterThan(testCase, localField(nearIdx), localField(farIdx), ...
        'Field should decay with distance from source');
end

function testHeatLocalizationSmallTau(testCase)
    % Test: Localize heat filter with small tau (localized response)
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    E = fixture.E;  % Use precomputed eigenmodes from fixture
    
    F = bct.filter.design(E.values, "Heat", "tau", 1);
    
    vertexIdx = 500;
    localField = bct.manifold.operator.localize(M, vertexIdx, F);
    
    % Verify output
    verifySize(testCase, localField, [M.nVertices, 1]);
    verifyTrue(testCase, all(isfinite(localField)));
    
    % Small tau should give more localized response
    % Count how many vertices have significant response (>1% of max)
    maxVal = max(localField);
    significantVertices = sum(localField > 0.01 * maxVal);
    
    % Should be relatively small compared to total vertices
    verifyLessThan(testCase, significantVertices, 0.1 * M.nVertices, ...
        'Small tau should give localized response');
end

function testHeatLocalizationLargeTau(testCase)
    % Test: Localize heat filter with large tau (spread response)
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    E = fixture.E;  % Use precomputed eigenmodes from fixture
    
    F = bct.filter.design(E.values, "Heat", "tau", 100);
    
    vertexIdx = 500;
    localField = bct.manifold.operator.localize(M, vertexIdx, F);
    
    % Verify output
    verifySize(testCase, localField, [M.nVertices, 1]);
    verifyTrue(testCase, all(isfinite(localField)));
    
    % Large tau should give more spread response
    % Count how many vertices have significant response (>1% of max)
    maxVal = max(localField);
    significantVertices = sum(localField > 0.01 * maxVal);
    
    % Should affect larger portion of mesh
    verifyGreaterThan(testCase, significantVertices, 0.2 * M.nVertices, ...
        'Large tau should give spread response');
end

%% ========================================================================
%% FILTERBANK LOCALIZATION
%% ========================================================================

function testFilterbankLocalization(testCase)
    % Test: Localize filterbank (multiple scales) at once
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    E = fixture.E;  % Use precomputed eigenmodes from fixture
    
    % Design filterbank with multiple tau values
    taus = [1, 5, 10, 20];
    F = bct.filter.design(E.values, "Heat", "tau", taus);
    
    % Localize filterbank at vertex 1000
    vertexIdx = 1000;
    localFields = bct.manifold.operator.localize(M, vertexIdx, F);
    
    % Verify output is [nVertices × J] where J = length(taus)
    verifySize(testCase, localFields, [M.nVertices, length(taus)], ...
        'Filterbank should return [nVertices × J] array');
    
    % Verify all columns are finite
    verifyTrue(testCase, all(isfinite(localFields(:))), ...
        'All filterbank outputs should be finite');
    
    % Verify each scale has maximum at or near vertex 1000
    for j = 1:length(taus)
        [~, maxIdx] = max(localFields(:, j));
        distance = abs(maxIdx - vertexIdx);
        verifyLessThanOrEqual(testCase, distance, 50, ...
            sprintf('Scale %d maximum should be near vertex 1000', j));
    end
    
    % Verify spreading increases with tau
    % Larger tau should have more vertices above threshold
    maxVals = max(localFields, [], 1);
    for j = 1:length(taus)-1
        count_j = sum(localFields(:, j) > 0.01 * maxVals(j));
        count_j1 = sum(localFields(:, j+1) > 0.01 * maxVals(j+1));
        verifyGreaterThan(testCase, count_j1, count_j, ...
            sprintf('Tau=%d should be more spread than tau=%d', taus(j+1), taus(j)));
    end
end

function testFilterbankCellOutput(testCase)
    % Test: Localize filterbank with cell array output format
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    E = fixture.E;  % Use precomputed eigenmodes from fixture (100 modes)
    
    % Design filterbank (use first 50 eigenvalues for this test)
    E_subset = struct('values', E.values(1:50), 'vectors', E.vectors(:, 1:50));
    taus = [5, 15, 30];
    F = bct.filter.design(E_subset.values, "Heat", "tau", taus);
    
    % Localize with cell output format
    vertexIdx = 500;
    localFields = bct.manifold.operator.localize(M, vertexIdx, F, ...
        'OutputFormat', 'cell');
    
    % Verify output is cell array
    verifyClass(testCase, localFields, 'cell');
    verifySize(testCase, localFields, [1, length(taus)], ...
        'Cell output should be {1 × J}');
    
    % Verify each cell contains [nVertices × 1] array
    for j = 1:length(taus)
        verifyClass(testCase, localFields{j}, 'double');
        verifySize(testCase, localFields{j}, [M.nVertices, 1]);
        verifyTrue(testCase, all(isfinite(localFields{j})));
    end
end

%% ========================================================================
%% INPUT VALIDATION
%% ========================================================================

function testInvalidVertexIndex(testCase)
    % Test: Invalid vertex index should error
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    E = fixture.E;  % Use precomputed eigenmodes from fixture (100 modes)
    
    % Use first 50 eigenvalues for this test
    F = bct.filter.design(E.values(1:50), "Heat", "tau", 10);
    
    % Test vertex index = 0
    verifyError(testCase, ...
        @() bct.manifold.operator.localize(M, 0, F), ...
        'bct:manifold:operator:localize:InvalidVertexIndex');
    
    % Test vertex index > nVertices
    verifyError(testCase, ...
        @() bct.manifold.operator.localize(M, M.nVertices + 1, F), ...
        'bct:manifold:operator:localize:InvalidVertexIndex');
    
    % Test non-integer vertex index
    verifyError(testCase, ...
        @() bct.manifold.operator.localize(M, 100.5, F), ...
        '');  % Should fail validation
end

function testBoundaryVertexLocalization(testCase)
    % Test: Localization at boundary vertex (edge case)
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    E = fixture.E;  % Use precomputed eigenmodes from fixture (100 modes)
    
    % Use first 50 eigenvalues for this test
    F = bct.filter.design(E.values(1:50), "Heat", "tau", 10);
    
    % Test at first vertex
    localField1 = bct.manifold.operator.localize(M, 1, F);
    verifySize(testCase, localField1, [M.nVertices, 1]);
    verifyTrue(testCase, all(isfinite(localField1)));
    
    % Test at last vertex
    localFieldN = bct.manifold.operator.localize(M, M.nVertices, F);
    verifySize(testCase, localFieldN, [M.nVertices, 1]);
    verifyTrue(testCase, all(isfinite(localFieldN)));
    
    % Both should have positive maximum
    verifyGreaterThan(testCase, max(localField1), 0);
    verifyGreaterThan(testCase, max(localFieldN), 0);
end
