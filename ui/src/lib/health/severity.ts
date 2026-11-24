// Injury severity palette (Figma "Health and injuries"): solid accent, 14% card fill, 47% card border
import type { Severity } from './health.svelte';

export const SEVERITY_COLORS: Record<Severity, { solid: string; bg: string; border: string }> = {
	critical: { solid: '#fb3244', bg: 'rgba(251, 50, 68, 0.14)', border: 'rgba(251, 50, 68, 0.47)' },
	major: { solid: '#ea6243', bg: 'rgba(234, 98, 67, 0.14)', border: 'rgba(234, 98, 67, 0.47)' },
	minor: { solid: '#ed944d', bg: 'rgba(237, 148, 77, 0.14)', border: 'rgba(237, 148, 77, 0.47)' },
};
