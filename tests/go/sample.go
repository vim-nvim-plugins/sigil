package main

import "fmt"

var total int

func add(a, b int) int {
	sum := a + b
	total += sum
	for i := 0; i < b; i++ {
		sum += i
	}
	return sum
}

func main() {
	s := add(1, 2)
	fmt.Println(s, total)
}
