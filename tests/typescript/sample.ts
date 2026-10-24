const limit: number = 3;
function scale(value: number, factor: number): number {
  let total = value * factor;
  for (let i = 0; i < limit; i++) total += i;
  return total;
}
function twice(value: number): number {
  const total = value * 2; // total in a comment
  return total;
}
class Box {
  w: number;
  constructor(w: number) { this.w = w; }
}
console.log("total limit", scale(limit, 2), new Box(1).w);
