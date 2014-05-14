immutable Transpose{T, N, S<:AbstractArray{T, N}, Conj} <: AbstractArray{T, N}
	data::S
end
typealias MatrixTranspose{T, S, Conj} Transpose{T, 2, S, Conj}
typealias VectorTranspose{T, S, Conj} Transpose{T, 1, S, Conj}
typealias Adjoint{T, S} Transpose{T, 2, S, true}
typealias Covector{T, S} Transpose{T, 1, S, true}

ctranspose{T, N}(A::AbstractArray{T, N}) = N <= 2 ? Transpose{T, N, typeof(A), true}(A) : throw(ArgumentError("dimension cannot be larger than two"))
transpose{T<:Real, N}(A::AbstractArray{T, N}) = N <= 2 ? Transpose{T, N, typeof(A), true}(A) : throw(ArgumentError("dimension cannot be larger than two"))
transpose{T, N}(A::AbstractArray{T, N}) = N <= 2 ? Transpose{T, N, typeof(A), false}(A) : throw(ArgumentError("dimension cannot be larger than two"))

ctranspose{T,N,S}(A::Transpose{T,N,S,true}) = A.data
transpose{T,N,S}(A::Transpose{T,N,S,false}) = A.data

size(A::VectorTranspose, args...) = size(A.data, args...)
size(A::MatrixTranspose) = reverse(size(A.data))
size(A::MatrixTranspose, dim::Integer) = dim == 1 ? size(A.data, 2) : (dim == 2 ? size(A.data, 1) : size(A.data, dim))

getindex(A::VectorTranspose, i::Integer) = getindex(A.data, i)
getindex(A::MatrixTranspose, i::Integer, j::Integer) = getindex(A.data, j, i)

## Transpose ##

const sqrthalfcache = 1<<7
function transpose!{T<:Number}(B::Matrix{T}, A::Matrix{T})
    m, n = size(A)
    if size(B) != (n,m)
        error("input and output must have same size")
    end
    elsz = isbits(T) ? sizeof(T) : sizeof(Ptr)
    blocksize = ifloor(sqrthalfcache/elsz/1.4) # /1.4 to avoid complete fill of cache
    if m*n <= 4*blocksize*blocksize
        # For small sizes, use a simple linear-indexing algorithm
        for i2 = 1:n
            j = i2
            offset = (j-1)*m
            for i = offset+1:offset+m
                B[j] = A[i]
                j += n
            end
        end
        return B
    end
    # For larger sizes, use a cache-friendly algorithm
    for outer2 = 1:blocksize:size(A, 2)
        for outer1 = 1:blocksize:size(A, 1)
            for inner2 = outer2:min(n,outer2+blocksize)
                i = (inner2-1)*m + outer1
                j = inner2 + (outer1-1)*n
                for inner1 = outer1:min(m,outer1+blocksize)
                    B[j] = A[i]
                    i += 1
                    j += n
                end
            end
        end
    end
    B
end

function full{T, S<:DenseMatrix}(A::MatrixTranspose{T, S, false})
   	B = similar(A, size(A, 2), size(A, 1))
   	transpose!(B, A)
end
function full{T, S<:DenseMatrix}(A::MatrixTranspose{T, S, true})
   	B = similar(A, size(A, 2), size(A, 1))
   	transpose!(B, A)
   	return conj!(B)
end

# full{T<:Real, S}(A::MatrixTranspose{T, S, true}) = transpose(A)

full(x::VectorTranspose) = x.data
full{T, S<:AbstractMatrix}(X::MatrixTranspose{T, S, false}) = [ X[i,j] for i=1:size(X,1), j=1:size(X,2) ]
full{T, S<:AbstractMatrix}(X::MatrixTranspose{T, S, true}) = [ conj(X[i,j]) for i=1:size(X,1), j=1:size(X,2) ]

	# *(x::VectorTranspose, y::AbstractVector) = dot(x.data, y)

	# *{T, S}(x::Covector{T, S}, A::AbstractMatrix{T}) = Transpose{T, 1, S, true}(Ac_mul_B(A, x.data))