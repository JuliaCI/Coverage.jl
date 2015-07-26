# Support functionality for amend_coverage_from_src!

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
    end
    infunction |= isfuncexpr(ast)
    for arg in ast.args
        flines = function_body_lines!(flines, arg, infunction)
    end
    flines
end