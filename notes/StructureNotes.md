Level 0: Substrate and metadata

Mesh

coordinate/frame metadata

Level 1: Differential and algebraic operators

Operator artifacts:

gradient, divergence, curl

Laplace–Beltrami

DEC incidence matrices d0, d1, Hodge stars star0, star1, star2

projection operators (vertex↔face, tangential projection)

plus the mass/Hodge structures they rely on

Decision point: mass matrix / cotan / Hodge stars are “operators,” but they are also “geometry-derived.”
Recommendation: store them as Operator artifacts with semantics="mass" or semantics="hodgeStar0", but implement them in geometry/operator packages internally—users should consume them as operators.

Level 2: Bases and spectral representations

Basis artifacts (eigenpairs)

Transform artifacts (coefficients, joint spectra)

Level 3: Derived measures / summaries

DerivedMeasure artifacts

(later) Event artifacts