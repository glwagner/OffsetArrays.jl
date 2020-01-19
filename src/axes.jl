"""
    ro = IdOffsetRange(r::AbstractUnitRange, offset=0)

Construct an "identity offset range". Numerically, `collect(ro) == collect(r) .+ offset`,
with the additional property that `axes(ro) = (ro,)`, which is where the "identity" comes from.

# Examples

The most common case is shifting a range that starts at 1 (either `1:n` or `Base.OneTo(n)`):
```jldoctest
julia> ro = OffsetArrays.IdOffsetRange(1:3, -2)
-1:1

julia> ro[-1]
-1

julia> ro[3]
ERROR: BoundsError: attempt to access 3-element UnitRange{Int64} at index [5]
```

If the range doesn't start at 1, the values may be different from the indices:
```jldoctest
julia> ro = OffsetArrays.IdOffsetRange(11:13, -2)
9:11

julia> ro[-1]
9

julia> ro[3]
ERROR: BoundsError: attempt to access 3-element UnitRange{Int64} at index [5]
```

# Extended help

Construction/coercion preserves the (shifted) values of the input range, but may modify
the indexes if required by the specified types. For example,

   r = OffsetArrays.IdOffsetRange{Int,UnitRange{Int}}(3:4)

has `r[1] == 3` and `r[2] == 4`, whereas

   r = OffsetArrays.IdOffsetRange{Int,Base.OneTo{Int}}(3:4)

has `r[3] == 3` and `r[4] == 4`, and `r[1]` would throw a `BoundsError`.
In this latter case, a shift in the axes was needed because `Base.OneTo` ranges
must start with value 1.

In contrast, *conversion* preserves both the values and the indices, throwing an error
when this is not achievable. For instance,

    r = convert(OffsetArrays.IdOffsetRange{Int,UnitRange{Int}}, 3:4)

has `r[1] == 3` and `r[2] == 4` and would satisfy `r == 3:4`, whereas

```jldoctest
julia> convert(OffsetArrays.IdOffsetRange{Int,Base.OneTo{Int}}, 3:4)
ERROR: ArgumentError: first element must be 1, got 3
```

where the error arises because the result could not have the same axes as the input.
"""
struct IdOffsetRange{T<:Integer,I<:AbstractUnitRange{T}} <: AbstractUnitRange{T}
    parent::I
    offset::T

    IdOffsetRange{T,I}(r::I, offset::T) where {T<:Integer,I<:AbstractUnitRange{T}} = new{T,I}(r, offset)
end

# Construction/coercion from arbitrary AbstractUnitRanges
function IdOffsetRange{T,I}(r::AbstractUnitRange, offset::Integer = 0) where {T<:Integer,I<:AbstractUnitRange{T}}
    rc, o = offset_coerce(I, r)
    return IdOffsetRange{T,I}(rc, convert(T, o+offset))
end
function IdOffsetRange{T}(r::AbstractUnitRange, offset::Integer = 0) where T<:Integer
    rc = convert(AbstractUnitRange{T}, r)::AbstractUnitRange{T}
    return IdOffsetRange{T,typeof(rc)}(rc, convert(T, offset))
end
IdOffsetRange(r::AbstractUnitRange{T}, offset::Integer = 0) where T<:Integer =
    IdOffsetRange{T,typeof(r)}(r, convert(T, offset))

# Coercion from other IdOffsetRanges
IdOffsetRange{T,I}(r::IdOffsetRange{T,I}) where {T<:Integer,I<:AbstractUnitRange{T}} = r
function IdOffsetRange{T,I}(r::IdOffsetRange) where {T<:Integer,I<:AbstractUnitRange{T}}
    rc, offset = offset_coerce(I, r.parent)
    return IdOffsetRange{T,I}(rc, r.offset+offset)
end
function IdOffsetRange{T}(r::IdOffsetRange) where T<:Integer
    return IdOffsetRange(convert(AbstractUnitRange{T}, r.parent), r.offset)
end
IdOffsetRange(r::IdOffsetRange) = r

# Conversion preserves both the values and the indexes, throwing an InexactError if this
# is not possible.
Base.convert(::Type{IdOffsetRange{T,I}}, r::IdOffsetRange{T,I}) where {T<:Integer,I<:AbstractUnitRange{T}} = r
Base.convert(::Type{IdOffsetRange{T,I}}, r::IdOffsetRange) where {T<:Integer,I<:AbstractUnitRange{T}} =
    IdOffsetRange{T,I}(convert(I, r.parent), r.offset)
Base.convert(::Type{IdOffsetRange{T,I}}, r::AbstractUnitRange) where {T<:Integer,I<:AbstractUnitRange{T}} =
    IdOffsetRange{T,I}(convert(I, r), 0)

offset_coerce(::Type{Base.OneTo{T}}, r::Base.OneTo) where T<:Integer = convert(Base.OneTo{T}, r), 0
function offset_coerce(::Type{Base.OneTo{T}}, r::AbstractUnitRange) where T<:Integer
    o = first(r) - 1
    return Base.OneTo{T}(last(r) - o), o
end
# function offset_coerce(::Type{Base.OneTo{T}}, r::IdOffsetRange) where T<:Integer
#     rc, o = offset_coerce(Base.OneTo{T}, r.parent)

# Fallback, specialze this method if `convert(I, r)` doesn't do what you need
offset_coerce(::Type{I}, r::AbstractUnitRange) where I<:AbstractUnitRange{T} where T =
    convert(I, r), 0

@inline Base.axes(r::IdOffsetRange) = (Base.axes1(r),)
@inline Base.axes1(r::IdOffsetRange) = IdOffsetRange(Base.axes1(r.parent), r.offset)
@inline Base.unsafe_indices(r::IdOffsetRange) = (r,)
@inline Base.length(r::IdOffsetRange) = length(r.parent)

function Base.iterate(r::IdOffsetRange)
    ret = iterate(r.parent)
    ret === nothing && return nothing
    return (ret[1] + r.offset, ret[2])
end
function Base.iterate(r::IdOffsetRange, i) where T
    ret = iterate(r.parent, i)
    ret === nothing && return nothing
    return (ret[1] + r.offset, ret[2])
end

@inline Base.first(r::IdOffsetRange) = first(r.parent) + r.offset
@inline Base.last(r::IdOffsetRange) = last(r.parent) + r.offset

@propagate_inbounds Base.getindex(r::IdOffsetRange, i::Integer) = r.parent[i - r.offset] + r.offset
@propagate_inbounds function Base.getindex(r::IdOffsetRange, s::AbstractUnitRange{<:Integer})
    return r.parent[s .- r.offset] .+ r.offset
end

Base.show(io::IO, r::IdOffsetRange) = print(io, first(r), ':', last(r))

# Optimizations
@inline Base.checkindex(::Type{Bool}, inds::IdOffsetRange, i::Real) = Base.checkindex(Bool, inds.parent, i - inds.offset)
