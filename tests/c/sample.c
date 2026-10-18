#include <stdio.h>
static int counter = 0;
struct point { int x; int y; };
int add(int a, int b) {
	int sum = a + b;
	counter += sum;
	for (int i = 0; i < b; i++) sum += i;
	return sum;
}
int main(void) {
	struct point p = { 1, 2 };
	int sum = add(p.x, p.y); /* sum here */
	printf("%d %d\n", sum, counter);
	return 0;
}
