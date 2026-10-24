limit = 3
function scale(value, factor)
    total = value * factor
    for i in 1:limit
        total += i
    end
    return total
end
function twice(value)
    total = value * 2  # total in a comment
    return total
end
println("total limit", scale(limit, 2))
