val limit = 3
fun scale(value: Int, factor: Int): Int {
    var total = value * factor
    for (i in 0 until limit) {
        total += i
    }
    return total
}
fun twice(value: Int): Int {
    val total = value * 2 // total in a comment
    return total
}
fun main() { println("total limit " + scale(limit, 2)) }
