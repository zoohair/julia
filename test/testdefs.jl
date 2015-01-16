function runtests(name)
    if endswith(name,".jl")
        name = name[1:end-3]
    end
    println("     \033[1m*\033[0m \033[31m$(name)\033[0m")
    eval(Module(:__anon__), quote
        eval(x) = Core.eval(__anon__,x)
        const ARGS = Vector{UTF8String}[]
        using Base.Test
        include($("$name.jl"))
    end)
    nothing
end

function propagate_errors(a,b)
    if isa(a,Exception)
        rethrow(a)
    end
    if isa(b,Exception)
        rethrow(b)
    end
    nothing
end

# looking in . messes things up badly
filter!(x->x!=".", LOAD_PATH)
