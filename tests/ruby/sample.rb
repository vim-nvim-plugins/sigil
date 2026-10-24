LIMIT = 3
def scale(value, factor)
  total = value * factor
  [1, 2].each { |i| total += i }
  total
end
def twice(value)
  total = value * 2 # total in a comment
  total
end
class Box
  def initialize(w)
    @w = w
  end
end
puts "total LIMIT #{scale(LIMIT, 2)}"
class Pair
  def initialize(w)
    @w = w
  end
  def grow
    @w += 1
  end
end
