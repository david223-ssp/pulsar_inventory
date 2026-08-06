// pure formatting for cooldown/durability countdowns, components own their own ticking clock and re-derive text each tick
const DAY_MS = 1000 * 60 * 60 * 24;
const HOUR_MS = 1000 * 60 * 60;
const MIN_MS = 1000 * 60;

export function formatDuration(ms: number): string {
	if (ms <= 0) return '0 Seconds';

	const days = Math.floor(ms / DAY_MS);
	const hours = Math.floor((ms - days * DAY_MS) / HOUR_MS);
	const minutes = Math.floor((ms - days * DAY_MS - hours * HOUR_MS) / MIN_MS);
	const seconds = Math.floor((ms % MIN_MS) / 1000);

	const parts: string[] = [];
	if (days > 0) parts.push(`${days} ${days === 1 ? 'Day' : 'Days'}`);
	if (hours > 0 && hours < 24) parts.push(`${hours} ${hours === 1 ? 'Hour' : 'Hours'}`);
	if (minutes > 0 && hours < 60) parts.push(`${minutes} ${minutes === 1 ? 'Minute' : 'Minutes'}`);
	if (seconds > 0 && seconds < 60) parts.push(`${seconds} ${seconds === 1 ? 'Second' : 'Seconds'}`);

	return parts.length > 0 ? parts.join(' ') : '0 Seconds';
}
