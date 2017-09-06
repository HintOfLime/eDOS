// WOO! We are running in C!

void kernel_main () {
	// For now we just fill the screen with C's to prove that we actually running
	int c = 0x07000743;
	int i = 0xb8000;
	while (1) {
		*((int*)i)=c;
		i += 2;
	}
}