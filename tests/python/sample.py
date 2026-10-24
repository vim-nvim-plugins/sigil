import os
LIMIT = 10
def scale(value, factor=2, *rest, **opts):
    total = value * factor
    for i, x in enumerate(rest):
        total += i * x
    squares = [n * n for n in range(LIMIT)]
    return total + len(squares)

class Box:
    size = 3
    def __init__(self, w):
        self.w = w
        print(self.w, LIMIT)

total = scale(LIMIT)
print("total LIMIT", total)  # LIMIT in a comment

class Pair:
    def __init__(self, w):
        self.w = w
    def grow(self):
        self.w += 1
        return self.w

b = Box(1)
print(b.w)
