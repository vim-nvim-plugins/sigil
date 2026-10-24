class Counter {
	int total = 0;
	int Add(int step, int times) {
		int sum = 0;
		for (int i = 0; i < times; i++) { sum += step; }
		total += sum;
		return sum;
	}
	int Twice(int step) { int sum = step * 2; return sum; }
	string Label() { return "sum total"; } // sum in a comment
}
