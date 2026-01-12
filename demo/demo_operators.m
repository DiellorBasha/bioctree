%% bct.operators System Guide
% This script demonstrates the complete operator system workflow

%% Setup
addpath('toolbox');
addpath('external');

% Create test manifold
[V, F] = icosphere(3);
M = bct.Manifold(struct('V', V, 'F', F));

fprintf('=== bct.operators: Complete Guide ===\n\n');

%% 1. REGISTRY LAYER - Static Operator Definitions
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('1. REGISTRY: Static Operator Definitions\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

% Get all registered operator specifications
specs = bct.registry.operators.defs();
fprintf('Total registered operators: %d\n\n', specs.numEntries);

% Show example spec
spec = specs('gradient.dec');
fprintf('Example: gradient.dec specification:\n');
fprintf('  ID: %s\n', spec.id);
fprintf('  Name: %s\n', spec.name);
fprintf('  Domain: %s\n', spec.domain);
fprintf('  Input: %s\n', spec.inputType);
fprintf('  Output: %s\n', spec.outputType);
fprintf('  Backend: %s\n\n', spec.dependency.provider);

fprintf('KEY OPERATOR TYPES:\n');
fprintf('  - gradient.*    : scalar → vector (∇)\n');
fprintf('  - divergence.*  : vector → scalar (∇·)\n');
fprintf('  - laplacian.*   : scalar → scalar (Δ)\n');
fprintf('  - curl.*        : vector → scalar/vector\n');
fprintf('  - hhd.*         : Helmholtz-Hodge decomposition\n\n');

fprintf('BACKENDS:\n');
fprintf('  .dec   - Discrete Exterior Calculus (DECLab)\n');
fprintf('  .fem   - Finite Element Method (gptoolbox)\n');
fprintf('  .graph - Graph-theoretic (GSPBox)\n\n');"