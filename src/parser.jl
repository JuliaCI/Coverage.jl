# Support functionality for amend_coverage_from_src!

isevaldef(x) = Base.Meta.isexpr(x, :(=)) && Base.Meta.isexpr(x.args[1], :call) &&
               x.args[1].args[1] == :eval

isfuncexpr(ex::Expr) =
    ex.head == :function || (ex.head == :(=) && typeof(ex.args[1]) == Expr && ex.args[1].head == :call)
isfuncexpr(arg) = false

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

    if isfuncexpr(ast) && length(args)>=2 && args[2] isa Expr
        # Only look in function body
        for arg in args[2].args
            flines = function_body_lines!(flines, arg, true)
        end
    else
        for arg in args
            flines = function_body_lines!(flines, arg, infunction)
        end
    end

    flines
end
