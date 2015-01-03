###

type RefValue{T} <: Ref{T}
    x::T
    RefValue() = new()
    RefValue(x) = new(x)
end
convert{T}(::Type{Ref{T}}, x::Ref{T}) = x
convert{T}(::Type{Ref{T}}, x) = RefValue{T}(x)
call{T}(::Type{Ref{T}}) = RefValue{T}()
eltype{T}(x::Type{Ref{T}}) = T

Ref(x::Ref) = x
Ref{T}(x::T) = RefValue{T}(x)
Ref{T}(x::Ptr{T}, i::Integer=1) = x + (i-1)*Core.sizeof(T)
Ref(x, i::Integer) = (i != 1 && error("Object only has one element"); Ref(x))

function Base.convert{T}(P::Type{Ptr{T}}, b::RefValue{T})
    if isbits(T) || T == Any
        return convert(P, data_pointer_from_objref(b))
    else
        return convert(P, data_pointer_from_objref(b.x))
    end
end
Base.convert{T}(::Type{Ptr{Void}}, b::RefValue{T}) = Base.convert(Ptr{Void}, Base.convert(Ptr{T}, b))

###

# note: the following type definitions don't mean any AbstractArray is convertible to
# a data Ref. they just map the array element type to the pointer type for
# convenience in cases that work.
pointer{T}(x::AbstractArray{T}) = convert(Ptr{T},x)
pointer{T}(x::AbstractArray{T}, i::Integer) = convert(Ptr{T},x) + (i-1)*elsize(x)

immutable RefArray{T, A<:AbstractArray} <: Ref{T}
    x::A
    i::Int
    RefArray(x,i) = (@assert(eltype(A) == T); new(x,i))
end
convert{T}(::Type{Ref{T}}, x::AbstractArray{T}) = RefArray{T,typeof(x)}(x, 1)
Ref{T}(x::AbstractArray{T}, i::Integer=1) = RefArray{T,typeof(x)}(x, i)

function Base.convert{T}(P::Type{Ptr{T}}, b::RefArray{T})
    if isbits(T) || T == Any
        convert(P, pointer(b.x, b.i))
    else
        convert(P, data_pointer_from_objref(b.x[b.i]))
    end
end
Base.convert{T}(::Type{Ptr{Void}}, b::RefArray{T}) = Base.convert(Ptr{Void}, Base.convert(Ptr{T}, b))

###

immutable RefArrayND{T, A<:AbstractArray} <: Ref{T}
    x::A
    i::(Int...)
    RefArrayND(x,i) = (@assert(eltype(A) == T); new(x,i))
end
Ref{A<:AbstractArray}(x::A, i::Integer...) = RefArrayND{eltype(A),A}(x, i)
Ref{A<:AbstractArray}(x::A, i::(Integer...)) = RefArrayND{eltype(A),A}(x, i)

function Base.convert{T}(P::Type{Ptr{T}}, b::RefArrayND{T})
    if isbits(T) || T == Any
        convert(P, pointer(b.x, b.i...))
    else
        convert(P, data_pointer_from_objref(b.x[b.i...]))
    end
end
Base.convert{T}(::Type{Ptr{Void}}, b::RefArrayND{T}) = Base.convert(Ptr{Void}, Base.convert(Ptr{T}, b))

###

immutable RefArrayI{T} <: Ref{T}
    x::AbstractArray{T}
    i::Tuple
    RefArrayI(x,i::ANY) = (@assert(eltype(A) == T); new(x,i))
end
Ref{T}(x::AbstractArray{T}, i...) = RefArrayI{T}(x, i)
Ref{T}(x::AbstractArray{T}, i::Tuple) = RefArrayI{T}(x, i)

function Base.convert{T}(P::Type{Ptr{T}}, b::RefArrayI{T})
    if isbits(T) || T == Any
        convert(P, pointer(b.x, b.i...))
    else
        convert(P, data_pointer_from_objref(b.x[b.i...]))
    end
end
Base.convert{T}(::Type{Ptr{Void}}, b::RefArrayI{T}) = Base.convert(Ptr{Void}, Base.convert(Ptr{T}, b))

###

Base.getindex(b::RefValue) = b.x
Base.getindex(b::RefArray) = b.x[b.i]
Base.getindex(b::RefArrayND) = b.x[b.i...]
Base.getindex(b::RefArrayI) = b.x[b.i...]

Base.setindex!(b::RefValue, x) = (b.x = x; b)
Base.setindex!(b::RefArray, x) = (b.x[b.i] = x; b)
Base.setindex!(b::RefArrayND, x) = (b.x[b.i...] = x; b)
Base.setindex!(b::RefArrayI, x) = (b.x[b.i...] = x; b)

###
