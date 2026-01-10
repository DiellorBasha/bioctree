is a very strong implementation conceptually, but it is currently overloaded relative to the architecture you have now formalized. The good news is that almost nothing here is “wrong” mathematically—the issue is where responsibilities live and what is canonical vs derived.

I will do three things:

Evaluate your current Graph against the new architecture (what to keep, what to move)

Define the corrected role of MATLAB graph as a plugin representation (important)

Give you a concrete refactoring plan:
– what stays in bct.Graph
– what moves to bct.graph.*
– what becomes a derived / cached representation

This will preserve all your functionality (shortest paths, flows, BFS/DFS, etc.) while making the design future-proof.

1. Key architectural clarification (this resolves the tension)

A MATLAB graph object is not a core representation.
It is a derived adapter that enables algorithms.

That means:

MATLAB graph is not the Graph

MATLAB graph is a view / backend / plugin

It must never be canonical

It is allowed to be cached

Your intuition here is correct:

“representing Graph as a MATLAB graph object which enables MATLAB graph functions as a plugin”

Yes — exactly — as a plugin.

2. What should be canonical in bct.Graph
Canonical = “source of truth”

The following are correctly conceptualized as canonical and should remain owned by bct.Graph:

✅ Keep in bct.Graph

Core identity

Manifold

N / NumNodes

Topology

Edges (explicit 1-simplices — very good that you store them)

(Optionally) adjacency as a logical topology, but see below

Metric overlays (conceptually valid)

Weights.geometry

Weights.fem

user-defined metrics

Cache management

versioning

invalidation

Conceptual access

“give me a graph with this metric”

“give me neighbors”

“give me distances”

These are graph semantics, not algorithms.

3. What should NOT be canonical (and must move)

The following currently violate your own newer contracts:

❌ Should NOT live in bct.Graph
Current content	Why
buildAdjacency	Assembly algorithm → backend
buildDegree	Numerical operator → backend
buildLaplacian	Operator assembly → backend
GraphGSPCache	External backend representation
GSPBox-specific code	External plugin
MATLAB graph construction logic	External plugin
shortestPath, bfSearch, etc.	Algorithm execution

None of these should be owned by the Graph class.

4. Correct mental model (this is the key shift)
The Graph class should say:

“I am a graph concept derived from a Manifold.
I can expose myself to different computational backends.”

Backends include:

MATLAB graph

GSPBox graph

future GPU / C++ / networkx adapters

5. The corrected role of bct.Graph
Final responsibilities of bct.Graph
bct.Graph
│
├─ Identity
│   └─ Manifold
│
├─ Topology (canonical)
│   ├─ Edges
│   └─ NumNodes
│
├─ Metrics (canonical)
│   └─ Weights (geometry, fem, custom)
│
├─ Representation adapters (delegation only)
│   ├─ matlab(metric)
│   ├─ gsp(metric)
│   └─ incidence()
│
└─ Spectral access
    └─ eigenpairs(k)


Importantly:

Adapters delegate to bct.graph.*

No assembly logic lives in the class

6. Where MATLAB graph logic should live
Move this logic to +bct/+graph
+bct/+graph/
├─ assembleAdjacency.m
├─ assembleDegree.m
├─ assembleLaplacian.m
├─ matlabGraph.m
├─ gspGraph.m
├─ shortestPath.m
├─ bfSearch.m
├─ dfSearch.m
├─ distances.m
├─ maxFlow.m
├─ eigensolve.m


Each function:

takes a bct.Graph object

returns a result

is pure (no hidden state)

7. Refactored bct.Graph (recommended target)

Below is a condensed but architecturally correct version of your class.

classdef Graph < handle

    properties (SetAccess = private)
        Manifold
        Edges
        Weights
        NumNodes
    end

    properties (Access = private)
        Cache
        EigenpairCache
    end

    methods
        function obj = Graph(M)
            obj.Manifold  = M;
            obj.Edges     = M.Edges;          % canonical
            obj.NumNodes  = size(M.Vertices,1);
            obj.Weights   = struct();
            obj.Cache     = containers.Map();
            obj.EigenpairCache = containers.Map();

            obj.computeGeometricWeights();
            obj.computeFEMWeights();
        end

        % --- Metrics ---
        function computeGeometricWeights(obj)
            obj.Weights.geometry = ...
                bct.graph.edgeLengths(obj.Manifold);
        end

        function computeFEMWeights(obj)
            obj.Weights.fem = ...
                bct.graph.femWeights(obj.Manifold);
        end

        % --- Adapters ---
        function G = matlab(obj, metric)
            G = bct.graph.matlabGraph(obj, metric);
        end

        function G = gsp(obj, metric)
            G = bct.graph.gspGraph(obj, metric);
        end

        function B = incidence(obj)
            B = bct.graph.incidence(obj);
        end

        % --- Spectral ---
        function E = eigenpairs(obj, k)
            key = sprintf("k=%d", k);
            if ~isKey(obj.EigenpairCache, key)
                obj.EigenpairCache(key) = bct.graph.eigensolve(obj, k);
            end
            E = obj.EigenpairCache(key);
        end
    end
end


This keeps all meaning, removes all algorithmic clutter, and aligns perfectly with FEM/DEC.

8. What happens to shortest paths, BFS, etc.?

They move here:

[path, dist] = bct.graph.shortestPath(G, s, t, metric);
T            = bct.graph.bfSearch(G, s, metric);


Optionally, you may keep thin convenience wrappers:

function [p,d] = shortestPath(obj,s,t,metric)
    [p,d] = bct.graph.shortestPath(obj,s,t,metric);
end


This is acceptable because it does not re-implement logic.

9. Why this design is better (important)
You gain:

Clean symmetry with FEM and DEC

Unlimited backend extensibility

Ability to swap MATLAB graph for other engines

A clean plugin architecture

Clear ownership of topology vs algorithms

Easier testing (backend functions are pure)

You lose nothing:

All MATLAB graph algorithms still available

All caching still possible

All metrics still supported

10. Final invariant (pin this)

bct.Graph defines graph meaning.
bct.graph executes graph algorithms.
MATLAB graph is a backend, not the graph.

If you hold to this invariant, your navigation layer will scale exactly as your spectral layer has.