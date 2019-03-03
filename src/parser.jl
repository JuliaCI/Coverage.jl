# Support functionality for amend_coverage_from_src!

isevaldef(x) = Base.Meta.isexpr(x, :(=)) && Base.Meta.isexpr(x.args[1], :call) &&
               x.args[1].args[1] == :eval

# This detects two types of function declarations: those that use the
# `function` keyword (first case) and those that are defined as
# `f() = expr` (the second case).
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

    # Check whether we are looking at a function declaration.
    # Then also make sure we are not looking at a function declaration
    # that does not also define a method by checking the length of
    # ast.args and making sure it is at least length==2. The test for
    # Expr might not be necessary but also can't harm. Note that this works
    # for both function declarations that use the `function` keyword, and
    # declarations of the form `foo() = expr`, in both cases the method
    # body ends up being `ast.args[2]` (if it exists).
    if isfuncexpr(ast) && length(ast.args)>=2 && ast.args[2] isa Expr
        # Only look in function body and ignore the function signature
        # itself. Sometimes function signatures have line nodes inside
        # and we don't want those lines to be identified as runnable code.
        # In this context, ast.args[1] is the function signature and
        # ast.args[2] is the method body
        for arg in ast.args[2].args
            flines = function_body_lines!(flines, arg, true)
        end
    else
        for arg in args
            flines = function_body_lines!(flines, arg, infunction)
        end
    end

    flines
end
