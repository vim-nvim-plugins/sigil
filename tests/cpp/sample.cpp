#include <vector>
int limit = 3;
struct Box { int w; };
int scale(int value, int factor) {
	int total = value * factor;
	for (int i = 0; i < limit; i++) total += i;
	return total;
}
int main() {
	Box b{2};
	int total = scale(b.w, limit); // total in a comment
	std::vector<int> xs = {total};
	for (auto x : xs) total += x;
	return total;
}
