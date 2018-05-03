# Support functionality for amend_coverage_from_src!

isevaldef(x) = Base.Meta.isexpr(x, :(=)) && Base.Meta.isexpr(x.args[1], :call) &&
               x.args[1].args[1] == :eval

function_body_lines(ast) = function_body_lines!(Int[], ast, false)
function_body_lines!(flines, arg, infunction) = flines
function function_body_lines!(flines, node::LineNumberNode, infunction)
    line = node.line
    if infunction
        push!(flines, line)
    end
    flines
end
function function_body_lines!(flines, ast::Expr, infunction)
    if ast.head == :line
        line = ast.args[1]
        if infunction
            push!(flines, line)
        end
        return flines
    elseif ast.head == :module
        # Ignore automatically added eval definitions
        args = ast.args[end].args
        if length(args) >= 2 && isevaldef(args[1]) && isevaldef(args[2])
            args = args[3:end]
        end
    else
        args = ast.args
    end
    infunction |= isfuncexpr(ast)
    for arg in args
        flines = function_body_lines!(flines, arg, infunction)
    end
    flines
end

if VERSION >= v"0.7.0-DEV.4881"
    function _parse(io::IO)
        pos = position(io) + 1
        str = read(io, String)
        ex, pos2 = Meta.parse(str, 1)
        seek(io, pos+pos2 - 2)
        ex
    end
elseif VERSION >= v"0.7.0-DEV.2437"
    function _parse(io::IO)
        # position(io) is 0-based
        Meta.parse(read(io, String), position(io)+1)
    end
else
    _parse(io::IO) = Base.parse(io)
end
