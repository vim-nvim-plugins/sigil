class Counter {
	int total = 0;
	int add(int step, int times) {
		int sum = 0;
		for (int i = 0; i < times; i++) { sum += step; }
		this.total += sum;
		return sum;
	}
	int twice(int step) { int sum = step * 2; return sum; }
	String label() { return "sum total"; } // sum in a comment
}
