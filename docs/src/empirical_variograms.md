# Empirical variograms

An empirical variogram has the form:

```math
\newcommand{\x}{\boldsymbol{x}}
\hat{\gamma}(h) = \frac{1}{2|N(h)|} \sum_{(i,j) \in N(h)} (z_i - z_j)^2
```

where ``N(h) = \left\{(i,j) \mid ||\x_i - \x_j|| = h\right\}`` is the set
of pairs of locations at a distance ``h`` and ``|N(h)|`` is the cardinality
of the set.

This package currently implements a simple ominidirectional (cross-)variogram.
Other more flexible types are planned for future releases.

As a unique feature, empirical variograms can be estimated using general
distance functions. These can be used in order to for example:

- Model anisotropy (e.g. ellipsoid distance)
- Perform geostatistical simulation on spherical coordinate systems (e.g. haversine distance)

Please see [Distances.jl](https://github.com/JuliaStats/Distances.jl)
for a complete list of options.

## Omnidirectional (cross-)variogram

```@docs
EmpiricalVariogram
```
