local limit = 3
local function grow(n, step)
  local acc = n
  for i = 1, limit do
    acc = acc + i * step
  end
  return acc
end
print(grow(limit, 2))
