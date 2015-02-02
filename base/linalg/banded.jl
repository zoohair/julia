## Banded matrices

importall Base

#Band storage format as used by LAPACK
#   http://www.netlib.org/lapack/lug/node124.html
#Type parameters:
# kl is the number of subdiagonals
# ku is the number of superdiagonals
# T: element type
# Fields:
# data: actual matrix elements
# nr: number of rows
immutable Banded{kl,ku,T} <: AbstractMatrix{T}
    data::Matrix{T}
    nr::Int
end

Banded(A::AbstractMatrix, kl::Int, ku::Int) = convert(Banded{kl, ku, eltype(A)}, A)

#TODO constructor that determines bandwidth of input

#Constructor: convert a matrix to band storage
function convert{kl,ku,S,T}(::Type{Banded{kl,ku,S}}, M::AbstractMatrix{T})
    m, n = size(M)
    data = zeros(S, kl+ku+1, n)
    #Columns of the matrix are stored in corresponding columns of the array,
    #and diagonals of the matrix are stored in rows of the array
    for j=1:n, i=1:kl+ku+1
        midx = j-ku-1+i
        1 ≤ midx ≤ m || continue
        data[i, j] = M[midx, j]
    end
    Banded{kl,ku,T}(data, m)
end

size(M::Banded) = (M.nr, size(M.data,2))
function size(M::Banded, d::Integer)
    if d<1
        throw(ArgumentError("dimension must be ≥ 1, got $d"))
    elseif d==1
        return M.nr
    elseif d==2
        return size(M.data,2)
    else
        return 1
    end
end

function full{kl,ku,T}(M::Banded{kl,ku,T})
    m, n = size(M)
    A = zeros(T, m, n)
    for j=1:n, i=1:kl+ku+1
        midx = j-ku-1+i
        1 ≤ midx ≤ m || continue
        A[midx, j] = M.data[i, j]
    end
    A
end

similar{kl,ku,T}(M::Banded{kl,ku,T}, args...) = Banded{kl,ku,T}(similar(M.data, args...), M.nr)

fill!{kl,ku,T}(M::Banded{kl,ku,T}, x::T) = (fill!(M.data, x); M)

##############################################################################
# Indexing
##############################################################################

#Cartesian indexing for single elements
function getindex{kl,ku,T}(M::Banded{kl,ku,T}, i::Int, j::Int)
    m, n = size(M)
    if 1 ≤ j ≤ n && 1 ≤ i ≤ m
        datarowidx = i-j+kl
        if 1 ≤ datarowidx ≤ kl+ku+1
            return M.data[datarowidx, j]
        else
            return zero(T)
        end
    else
        throw(BoundsError())
    end
end

#Linear indexing for single elements
function getindex{kl,ku,T}(M::Banded{kl,ku,T}, i::Int)
    j, i = divrem(i, size(M, 1))
    M[i, j+1]
end

##############################################################################
# Arithmetic
##############################################################################

+{kl,ku,T}(A::Banded{kl,ku,T}, B::Banded{kl,ku,T}) = Banded{kl,ku,T}(A.data + B.data)

#WIP
function +{kl,ku,T,ll,lu,U}(A::Banded{kl,ku,T}, B::Banded{ll,lu,U})
    l = max(kl, ll)
    u = max(ku, lu)
    S = promote_type(T, U)
    data = zeros(S, l, u)

    Banded{l,u,S}(data)
end

-{kl,ku,T}(A::Banded{kl,ku,T}, B::Banded{kl,ku,T}) = Banded{kl,ku,T}(A.data - B.data)

##############################################################################

#Tests
using Base.Test
let A=reshape(1:25,5,5)

B = convert(Banded{2,1,Int}, A)
@test B.data == #Note that the upper left and lower right corners are unused
   [0 6 12 18 24
    1 7 13 19 25
    2 8 14 20 0
    3 9 15 0 0]

@test size(B) == (5, 5)
@test_throws ArgumentError size(B, 0)
@test size(B, 1) == size(B, 2) == 5
@test size(B, 3) == 1
@test full(B) ==
   [1 6  0  0  0
    2 7 12  0  0
    3 8 13 18  0
    0 9 14 19 24
    0 0 15 20 25]

@test B[3, 1] == 3
@test B[1, 3] == 0
@test_throws BoundsError B[0, 0]
@test B[4] == 0
@test B[6] == 6
@test_throws BoundsError B[26]

C = similar(B)
fill!(C, -2)
@test size(C) == (5, 5)
@test size(C.data) == (4, 5)

@test all(C.data .== -2)

D = convert(Banded{1,1,Int}, A)
@test full(D) ==
   [1 6  0  0  0
    2 7 12  0  0
    0 8 13 18  0
    0 0 14 19 24
    0 0  0 20 25]

#@show B+C
#@show C+D
#@show C, D
#@show C+D
#@show full(C)+full(D)
end


