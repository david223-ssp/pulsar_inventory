// Tabler outline icons (24px grid, 2px stroke), the same set ox_inventory inlines, so nothing loads at runtime
export const TABLER = {
	play: ['M7 4v16l13 -8z'],
	drop: ['M4 20l16 0', 'M12 14l0 -10', 'M12 14l4 -4', 'M12 14l-4 -4'],
	star: ['M12 17.75l-6.172 3.245l1.179 -6.873l-5 -4.867l6.9 -1l3.086 -6.253l3.086 6.253l6.9 1l-5 4.867l1.179 6.873z'],
	copy: [
		'M7 9.667a2.667 2.667 0 0 1 2.667 -2.667h8.666a2.667 2.667 0 0 1 2.667 2.667v8.666a2.667 2.667 0 0 1 -2.667 2.667h-8.666a2.667 2.667 0 0 1 -2.667 -2.667z',
		'M4.012 16.737a2.005 2.005 0 0 1 -1.012 -1.737v-10c0 -1.1 .9 -2 2 -2h10c.75 0 1.158 .385 1.5 1',
	],
	backpack: ['M5 18v-6a6 6 0 0 1 6 -6h2a6 6 0 0 1 6 6v6a3 3 0 0 1 -3 3h-8a3 3 0 0 1 -3 -3z', 'M10 6v-1a2 2 0 1 1 4 0v1', 'M9 21v-4a3 3 0 0 1 6 0v4', 'M11 10h2'],
	send: ['M10 14l11 -11', 'M21 3l-6.5 18a.55 .55 0 0 1 -1 0l-3.5 -7l-7 -3.5a.55 .55 0 0 1 0 -1l18 -6.5'],
	split: ['M12 3v18', 'M8 7l-4 5l4 5', 'M16 7l4 5l-4 5'],
	dot: ['M12 12m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0'],
	give: ['M5 12l14 0', 'M13 18l6 -6', 'M13 6l6 6'],
	place: ['M12 4l0 12', 'M8 12l4 4l4 -4', 'M4 20l16 0'],
} as const;

export type TablerName = keyof typeof TABLER;
