# Method and method-table pretty-printing

function argtype_decl(n, t) # -> (argname, argtype)
    if isa(n,Expr)
        n = n.args[1]  # handle n::T in arg list
    end
    s = string(n)
    i = search(s,'#')
    if i > 0
        s = s[1:i-1]
    end
    if t === Any && !isempty(s)
        return s, ""
    end
    if t <: Vararg && t !== None && t.parameters[1] === Any
        return string(s, "..."), ""
    end
    return s, string(t)
end

function arg_decl_parts(m::Method, kwfunc::Bool=false)
    tv = m.tvars
    if !isa(tv,Tuple)
        tv = (tv,)
    end
    li = m.func.code
    e = uncompressed_ast(li)
    argnames = e.args[1]
    s = symbol("?")
    decls = [argtype_decl(get(argnames,i,s), m.sig[i]) for i=1:length(m.sig)]
    if kwfunc
        shift!(decls)
        kwargs = filter!(x->!('#' in string(x)), e.args[2][1])
    else
        kwargs = ()
    end
    return tv, decls, kwargs, li.file, li.line
end

function show(io::IO, m::Method; kwfunc::Bool=false)
    print(io, m.func.code.name)
    tv, decls, kwargs, file, line = arg_decl_parts(m, kwfunc)
    if !isempty(tv)
        show_delim_array(io, tv, '{', ',', '}', false)
    end
    print(io, "(")
    print_joined(io, [isempty(d[2]) ? d[1] : d[1]*"::"*d[2] for d in decls],
                 ",", ",")
    if kwfunc
        print(io, ";")
        print_joined(io, kwargs, ",", ",")
    end
    print(io, ")")
    if line > 0
        print(io, " at ", file, ":", line)
    end
end

function show_method_table(io::IO, mt::MethodTable, max::Int=-1, header::Bool=true, kwfunc::Bool=false)
    name = mt.name
    n = length(mt)
    if header
        m = n==1 ? "method" : "methods"
        print(io, "# $n $m for generic function \"$name\":")
    end
    d = mt.defs
    n = rest = 0
    while !is(d,())
        if max==-1 || n<max || (rest==0 && n==max && d.next === ())
            println(io)
            show(io, d; kwfunc=kwfunc)
            n += 1
        else
            rest += 1
        end
        d = d.next
    end
    if isdefined(mt, :kwsorter) && (max == -1 || n+length(mt.kwsorter)<max || (rest==0 && length(mt.kwsorter)==max))
        show_method_table(io, mt.kwsorter.env, max==-1 ? -1 : max-n, false, true)
    end
    if rest > 0
        println(io)
        print(io,"... $rest methods not shown (use methods($name) to see them all)")
    end
end

show(io::IO, mt::MethodTable) = show_method_table(io, mt)

inbase(m::Module) = m == Base ? true : m == Main ? false : inbase(module_parent(m))
function url(m::Method)
    if m.func.code.file == :none
        return ""
    end
    M = m.func.code.module
    file = string(m.func.code.file)
    line = m.func.code.line
    line <= 0 || ismatch(r"In\[[0-9]+\]", file) && return ""
    if inbase(M)
        return "https://github.com/JuliaLang/julia/tree/$(Base.GIT_VERSION_INFO.commit)/base/$file#L$line"
    else 
        try
            d = dirname(file)
            u = Git.readchomp(`config remote.origin.url`, dir=d)
            u = match(Git.GITHUB_REGEX,u).captures[1]
            root = cd(d) do # dir=d confuses --show-toplevel, apparently
                Git.readchomp(`rev-parse --show-toplevel`)
            end
            if beginswith(file, root)
                commit = Git.readchomp(`rev-parse HEAD`, dir=d)
                return "https://github.com/$u/tree/$commit/"*file[length(root)+2:end]*"#L$line"
            else
                return "file://"*find_source_file(file)
            end
        catch
            path = find_source_file(file)
            if path === nothing
                return ""
            end
            return "file://"*path
        end
    end
end

function writemime(io::IO, ::MIME"text/html", m::Method; kwfunc::Bool=false)
    print(io, m.func.code.name)
    tv, decls, kwargs, file, line = arg_decl_parts(m, kwfunc)
    if !isempty(tv)
        print(io,"<i>")
        show_delim_array(io, tv, '{', ',', '}', false)
        print(io,"</i>")
    end
    print(io, "(")
    print_joined(io, [isempty(d[2]) ? d[1] : d[1]*"::<b>"*d[2]*"</b>" 
                      for d in decls], ",", ",")
    if kwfunc
        print(io, ";<i>")
        print_joined(io, kwargs, ",", ",")
        print(io, "</i>")
    end
    print(io, ")")
    if line > 0
        u = url(m)
        if isempty(u)
            print(io, " at ", file, ":", line)
        else
            print(io, """ at <a href="$u" target="_blank">""", 
                  file, ":", line, "</a>")
        end
    end
end

function writemime(io::IO, mime::MIME"text/html", mt::MethodTable)
    name = mt.name
    n = length(mt)
    meths = n==1 ? "method" : "methods"
    print(io, "$n $meths for generic function <b>$name</b>:<ul>")
    d = mt.defs
    while !is(d,())
        print(io, "<li> ")
        writemime(io, mime, d)
        print(io, "</li> ")
        d = d.next
    end
    if isdefined(mt, :kwsorter)
        d = mt.kwsorter.env.defs
        while !is(d,())
            print(io, "<li> ")
            writemime(io, mime, d; kwfunc=true)
            print(io, "</li> ")
            d = d.next
        end
    end
    print(io, "</ul>")
end

# pretty-printing of Vector{Method} for output of methodswith:

function writemime(io::IO, mime::MIME"text/html", mt::AbstractVector{Method})
    print(io, summary(mt))
    if !isempty(mt)
        print(io, ":<ul>")
        for d in mt
            print(io, "<li> ")
            writemime(io, mime, d)
        end
        print(io, "</ul>")
    end
end

# override usual show method for Vector{Method}: don't abbreviate long lists
writemime(io::IO, mime::MIME"text/plain", mt::AbstractVector{Method}) =
    showarray(io, mt, limit=false)
