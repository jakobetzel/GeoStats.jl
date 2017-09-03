## Copyright (c) 2017, Júlio Hoffimann Mendes <juliohm@stanford.edu>
##
## Permission to use, copy, modify, and/or distribute this software for any
## purpose with or without fee is hereby granted, provided that the above
## copyright notice and this permission notice appear in all copies.
##
## THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
## WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
## MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
## ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
## WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
## ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
## OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

"""
    KrigParam

A set of parameters for a Kriging variable.

## Parameters

* `variogram` - Variogram model (default to `GaussianVariogram()`)
* `mean`      - Simple Kriging mean
* `degree`    - Universal Kriging degree
* `drifts`    - External Drift Kriging drift functions

Latter options override former options. For example, by specifying
`ds`, the user is telling the algorithm to ignore `d` and `m`.
If no option is specified, Ordinary Kriging is used by default with
the variogram `v` only.
"""
@with_kw struct KrigParam
  variogram = GaussianVariogram()
  mean = nothing
  degree = nothing
  drifts = nothing
end

"""
    Kriging(var₁=>param₁, var₂=>param₂, ...)

A polyalgorithm Kriging estimation solver.

Each pair `var=>param` specifies the [`KrigParam`](@ref) `param`
for the Kriging variable `var`. In order to avoid boilerplate
code, the constructor expects pairs of `Symbol` and `NamedTuple`
instead.

## Examples

Solve the variable `:var₁` with Simple Kriging by specifying
the `mean`, and the variable `:var₂` with Universal Kriging
by specifying the `degree` and the `variogram` model.

```julia
julia> Kriging(
  :var₁ => @NT(mean=1.),
  :var₂ => @NT(degree=1, variogram=SphericalVariogram(range=20.))
)
```

Solve all variables of the problem with the default parameters
(i.e. Ordinary Kriging with unit Gaussian variogram):

```julia
julia> Kriging()
```

### Notes

The prefix `@NT` extends for `NamedTuple`. It won't be necessary
in Julia v0.7 and beyond.
"""
struct Kriging <: AbstractEstimationSolver
  params::Dict{Symbol,KrigParam}

  Kriging(params::Dict{Symbol,KrigParam}) = new(params)
end

function Kriging(params...)
  # build dictionary for inner constructor
  dict = Dict{Symbol,KrigParam}()

  # convert named tuples to Kriging parameters
  for (varname, varparams) in params
    kwargs = [k => v for (k,v) in zip(keys(varparams), varparams)]
    push!(dict, varname => KrigParam(; kwargs...))
  end

  Kriging(dict)
end

function solve(problem::EstimationProblem, solver::Kriging)
  # sanity checks
  @assert keys(solver.params) ⊆ keys(variables(problem)) "invalid variable names in solver parameters"

  # determine problem coordinate type
  probcoords = coordinates(problem)
  T = promote_type([T for (var,T) in probcoords]...)

  # store results on dictionary
  μdict = Dict{Symbol,Vector}()
  σdict = Dict{Symbol,Vector}()

  # loop over target variables
  for (var,V) in variables(problem)
    # get user parameters
    if var ∈ keys(solver.params)
      varparams = solver.params[var]
    else
      varparams = KrigParam()
    end

    # determine which Kriging variant to use
    if varparams.drifts ≠ nothing
      estimator = ExternalDriftKriging{T,V}(varaparams.variogram, varparams.drifts)
    elseif varparams.degree ≠ nothing
      estimator = UniversalKriging{T,V}(varparams.variogram, varparams.degree)
    elseif varparams.mean ≠ nothing
      estimator = SimpleKriging{T,V}(varparams.variogram, varparams.mean)
    else
      estimator = OrdinaryKriging{T,V}(varparams.variogram)
    end

    # perform estimation
    varμ, varσ = solve(problem, var, estimator)

    # save result for variable
    μdict[var] = varμ
    σdict[var] = varσ
  end

  EstimationSolution(domain(problem), μdict, σdict)
end

function solve(problem::EstimationProblem, var::Symbol, estimator::E) where {E<:AbstractEstimator}
  # retrieve data
  spatialdata = data(problem)

  # find valid data for variable
  X, z = valid(spatialdata, var)

  # fit estimator to data
  fit!(estimator, X, z)

  # retrieve spatial domain
  pdomain = domain(problem)

  # pre-allocate memory for result
  varμ = Vector{eltype(z)}(npoints(pdomain))
  varσ = Vector{eltype(z)}(npoints(pdomain))

  # estimation loop
  for location in SimplePath(pdomain)
    x = coordinates(pdomain, location)
    μ, σ² = estimate(estimator, x)

    varμ[location] = μ
    varσ[location] = σ²
  end

  # return mean and variance
  varμ, varσ
end

# ------------
# IO methods
# ------------
function Base.show(io::IO, solver::Kriging)
  print(io, "Kriging solver")
end

function Base.show(io::IO, ::MIME"text/plain", solver::Kriging)
  println(io, solver)
  for (varname, varparams) in solver.params
    if varparams.drifts ≠ nothing
      println(io, "  - $varname => External Drift Kriging")
    elseif varparams.degree ≠ nothing
      println(io, "  - $varname => Universal Kriging")
    elseif varparams.mean ≠ nothing
      println(io, "  - $varname => Simple Kriging")
    else
      println(io, "  - $varname => Ordinary Kriging")
    end
  end
end
