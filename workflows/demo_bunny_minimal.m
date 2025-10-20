function demo_bunny_minimal()
% Minimal test of bunny pipeline to debug the error

fprintf('=== Minimal Bunny Test ===\n');

% Load data
dataPath = 'test-data/omega-tutorial/sub-0002/sensor/data_block001_band_02.mat';
data = load(dataPath);
megData = data.F;
fprintf('Loaded MEG data: %d x %d\n', size(megData));

% Create bunny graph
G_full = gsp_bunny();
fprintf('Full bunny: %d vertices\n', G_full.N);

% Select subset
nVertices = 50;  % Smaller for testing
rng(42);
vertexIndices = randperm(G_full.N, nVertices);
G = gsp_subgraph(G_full, vertexIndices);
G = gsp_estimate_lmax(G);
fprintf('Subgraph: %d vertices, %d edges\n', G.N, G.Ne);

% Map signals
X = megData(1:G.N, 1:100);  % Just first 100 samples
fprintf('Signal mapped: %d x %d\n', size(X));

% Test graph operations
try
    grad_X = graphGradient(G, X);
    fprintf('Gradient computed: %d x %d\n', size(grad_X));
    
    tv_X = graphTotalVariation(G, X, 1);
    fprintf('Total variation computed: %d x %d\n', size(tv_X));
    
    fprintf('Success!\n');
catch ME
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end

end