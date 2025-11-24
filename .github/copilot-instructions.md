📌 SYSTEM OVERVIEW — BIOCTREE / BCT TOOLBOX

You are working inside a MATLAB-based scientific computing toolbox called bioctree, whose core computational engine is the bct package.

Your purpose is to write and maintain code for a spectral signal-processing system that analyzes spatiotemporal signals defined on a mesh, using finite element methods (FEM) and Laplace–Beltrami operators.
This system is designed specifically for cortical mesh data (e.g., MEG/EEG source maps).

📦 PACKAGE STRUCTURE

The main package is:

toolbox/+bct/


It contains:

Core orchestrator class: @bct

Abstract base class for all domains: @Domain

Domain subclasses:

@Manifold

@Lambda

@Time

@Omega

@Joint

Other classes:

@Graph

@Signal

Subpackages:

+filters — filter kernels on domains

+io — load/save operations

+internal — utilities

+show — visualization subsystem

+sim — simulations

📚 CORE ARCHITECTURAL PRINCIPLE — DOMAIN INHERITANCE
✔ Every domain class inherits from a shared abstract class:
bct.Domain   (abstract)


All domain subclasses must:

extend bct.Domain

implement required abstract methods (e.g., size, axes, dual relationships)

define their transform behavior relative to their dual domain

Domain inheritance structure:

bct.Domain (abstract)
 ├── bct.Manifold   (mesh-based domain)
 ├── bct.Lambda     (dual of Manifold via eigenbasis)
 ├── bct.Time       (1D temporal domain)
 ├── bct.Omega      (dual of Time via Fourier transform)
 └── bct.Joint      (tensor product of 1D domains)


The coding agent must always respect this inheritance hierarchy.

📚 MAJOR CONCEPTS
1. Domains and Duals
Domain	Dual	Description
Manifold	Lambda	FEM mesh ↔ spatial eigenbasis
Time	Omega	time axis ↔ frequency axis

Transforms move signals between domains.

2. Transforms

Each dual pair defines a numerical transform:

Manifold ↔ Lambda using LB eigenvectors

Time ↔ Omega using FFT

All transforms must operate through domain objects, not ad-hoc code.

3. Signal Class

A signal is defined as:

S = bct.Signal(domain, data)


Signals are always associated with exactly one domain.

4. Filter Classes

Filters define kernels on a specific domain, or a joint domain.
Examples:

spatial low-pass filter on Lambda

temporal band-pass filter on Omega

spatiotemporal filter on Joint(Lambda, Omega)

time-varying spatial filter on Joint(Lambda, Time)

5. Joint Domain

A joint domain is a tensor product of 1D domains:

Joint = bct.Joint(Time, Lambda)


The visualizer and filter system must respect this structure when plotting or applying filters.

6. Bct Class (Orchestrator)

The bct class is the main entry point for:

constructing domains

computing eigenbasis

defining signals

performing transforms

building filters

orchestrating joint domain operations

saving/loading data

All operations across domains must run through bct.

📂 DATA LOCATIONS
Mesh test data:
data/mesh/fsaverage_rh_pial.mat  (or fsaverage_lh_pial.mat)

Contains variables:
- V  — vertices [N×3] double
- F  — faces [M×3] int32

Correct initialization:
```matlab
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);
```

Signal test data

Can be generated using the Signal class.

🧪 TESTING FRAMEWORK

All tests must go under:

tests/


Use MATLAB’s matlab.unittest framework.

Requirements:

create a BaseBctTest shared test superclass

BaseBctTest must run bioctree_start

all test classes must subclass BaseBctTest

Test categories:

unit tests for all domain subclasses

unit tests for transforms

unit tests for filters

unit tests for Signal class behavior

integration tests for pipeline (Manifold → Lambda → Omega → Joint)

performance tests (e.g., eigensolver speed)

📚 DOCUMENTATION REQUIREMENTS

All documentation must go under:

docs/


Documentation must describe:

domain inheritance hierarchy

dual mappings

transforms

signals

filters

visualizer usage

examples

API references

⚙ DEPENDENCIES

Bioctree uses external dependencies listed in:

config/bioctree_dependencies.json


The coding agent must handle these dependencies properly for imports and path setup.

🖥 FRONTEND / BACKEND DESIGN

The user interface lives in:

apps/app_code/BctFrontend.m


It calls:

apps/app_code/BctBackend.m


The backend must communicate with the bct class and all domain, signal, and filter classes.

No UI code should directly manipulate domain or signal objects — it must call the backend.

🎯 CODING AGENT EXPECTATIONS

When generating code, you must:

Respect the abstract Domain inheritance hierarchy

Use bct.Domain as the base for all domain subclasses

Use transforms to move signals between dual domains

Use the bct class as the orchestrator of all operations

Place code in the correct package

Write correct unit tests in tests/

Add or update documentation in docs/

Maintain clean, modular, MATLAB OOP style

Avoid code duplication by leveraging inheritance and domain polymorphism

Keep transform logic inside domain subclasses where appropriate

You must write code that integrates CLEANLY with the entire system described above.