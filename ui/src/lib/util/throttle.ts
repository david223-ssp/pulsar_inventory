export function throttle<Args extends unknown[]>(fn: (...args: Args) => void, waitMs: number): (...args: Args) => void {
	let lastCall = 0;
	return (...args: Args) => {
		const now = Date.now();
		if (now - lastCall < waitMs) return;
		lastCall = now;
		fn(...args);
	};
}
