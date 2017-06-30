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
    AbstractDistance

A metric or distance function.
"""
abstract type AbstractDistance end

"""
    EuclideanDistance

The Euclidean distance ||x-y||₂
"""
immutable EuclideanDistance <: AbstractDistance end
(d::EuclideanDistance)(x, y) = norm(x - y)

"""
    EllipsoidDistance(semiaxes, angles)

A distance defined by an ellipsoid with given `semiaxes` and rotation `angles`.

- For 2D ellipsoids, there are two semiaxes and one rotation angle.
- For 3D ellipsoids, there are three semiaxes and three rotation angles.

## Examples

2D ellipsoid making 45ᵒ with the horizontal axis:

```julia
julia> EllipsoidDistance([1.0,0.5], [π/2])
```

3D ellipsoid rotated by 45ᵒ in the xy plane:

```julia
julia> EllipsoidDistance([1.0,0.5,0.5], [π/2,0.0,0.0])
```

### Notes

The positive definite matrix representing the ellipsoid is assembled
once during object construction and cached for fast evaluation.
"""
immutable EllipsoidDistance{N,T<:Real} <: AbstractDistance
  A::Matrix{T}

  function EllipsoidDistance{N,T}(semiaxes, angles) where {N,T<:Real}
    @assert length(semiaxes) == N "number of semiaxes must match spatial dimension"
    @assert all(semiaxes .> zero(T)) "semiaxes must be positive"

    # scaling matrix
    Λ = spdiagm(one(T)./semiaxes.^2)

    # rotation matrix
    P = []
    if N == 2
      θ = angles[1]
      P = [cos(θ) -sin(θ)
           sin(θ)  cos(θ)]
    elseif N == 3
      @assert length(angles) == 3 "there must be three angles in 3D"
      θxy, θyz, θzx = angles
      Rxy = [cos(θxy) -sin(θxy) zero(T)
             sin(θxy)  cos(θxy) zero(T)
              zero(T)   zero(T)  one(T)]
      Ryz = [ one(T)  zero(T)   zero(T)
             zero(T) cos(θyz) -sin(θyz)
             zero(T) sin(θyz)  cos(θyz)]
      Rzx = [cos(θzx) zero(T) sin(θzx)
              zero(T)  one(T)  zero(T)
            -sin(θzx) zero(T) cos(θzx)]
      P = Rzx*Ryz*Rxy
    else
      error("ellipsoid distance not implemented for dimension > 3D")
    end

    # ellipsoid matrix
    A = P*Λ*P'

    new(A)
  end
end
EllipsoidDistance(semiaxes::Vector{T}, angles::Vector{T}) where {T<:Real} =
  EllipsoidDistance{length(semiaxes),T}(semiaxes, angles)
(d::EllipsoidDistance)(x, y) = (z = x-y; √(z'*d.A*z))
