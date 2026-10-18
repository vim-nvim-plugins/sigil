const MAX: i32 = 5;
fn add(a: i32, b: i32) -> i32 {
    let mut sum = a + b;
    for i in 0..MAX {
        sum += i;
    }
    sum
}
fn main() {
    let s = add(1, 2);
    println!("{} {}", s, MAX);
}
