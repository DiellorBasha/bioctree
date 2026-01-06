function specs = operators()
%OPERATORS Authoritative catalog of all operators in bct ecosystem
%
% ⚠️  FACADE: This function delegates to bct.registry.operators.defs()
%     which now returns a dictionary with hierarchical IDs.
%
% Syntax:
%   specs = bct.registry.operators()
%
% Returns:
%   specs - dictionary (string → struct) with operator specifications
%
% Each OperatorSpec has fields:
%   id              - Hierarchical identifier (e.g., "gradient.dec") (string)
%   name            - Display name (string)
%   domain          - "fem", "dec", "graph", "spectral", "kernel" (string)
%   representation  - Required class (e.g., "DiscreteExteriorCalculus") (string)
%   inputType       - Semantic type: "signal", "coefficients", "0-form", etc.
%   outputType      - Semantic output type (string)
%   formDegree      - DEC form degree (double or [])
%   parameters      - Required parameters (struct)
%   requires        - Required capabilities (string array)
%   dependency      - External toolbox dependency metadata (struct)
%   function        - Function handle to implementation
%   purity          - "pure" or "impure" (string)
%   description     - Human-readable description (string)
%
% Design principles (from OperatorsContract):
%   - Registry is declarative and static
%   - Registry describes what exists
%   - Registry never decides what runs
%   - Content is deterministic
%   - No runtime objects allowed
%
% Migration Note:
%   - Old struct-based IDs (dec_gradient, etc.) deprecated
%   - New hierarchical IDs (gradient.dec, gradient.fem, etc.)
%   - Dictionary allows dots in keys (not possible with struct fields)
%
% See also: bct.registry.operators.defs, bct.runtime.operators.dictionary

% Delegate to new implementation
specs = bct.registry.operators.defs();

end
