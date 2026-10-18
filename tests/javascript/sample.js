const base = 10;
let count = 0;
function bump(step, { by = 1 } = {}) {
  const next = count + step * by;
  count = next;
  return next + base;
}
const items = [1, 2].map((v) => v * base);
for (const item of items) { bump(item); }
obj.count = 5;
