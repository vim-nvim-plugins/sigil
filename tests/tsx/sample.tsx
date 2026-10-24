const limit = 3;
function Item({ label }: { label: string }) {
  const text = label + limit;
  return <li>{text}</li>;
}
function List(items: string[]) {
  const text = "text limit"; // text in a comment
  return <ul>{items.map((item) => <Item label={item + text} />)}</ul>;
}
