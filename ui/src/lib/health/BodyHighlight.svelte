<!-- Tints the silhouette's outline over each injured body part, in that part's worst severity color.
     The outline art (silhouette-body.svg) is used as a mask and clipped to the part's box, so no extra artwork is needed -->
<script lang="ts">
	import { healthState, type BodyPart, type Severity } from './health.svelte';
	import { SEVERITY_COLORS } from './severity';
	import silhouette from '../../assets/images/silhouette-body.svg';

	// part boxes on the outline as [left, top, right, bottom] in % of its frame. The silhouette mirrors the player's ped,
	// which faces away from the camera, so the character's left side is on the viewer's left
	const BOXES: Record<BodyPart, [number, number, number, number]> = {
		HEAD: [38, 0, 66, 14],
		NECK: [41, 12, 63, 19],
		UPPER_BODY: [29, 17, 75, 43],
		SPINE: [29, 17, 75, 43],
		LOWER_BODY: [31, 42, 73, 56],
		LARM: [4, 18, 33, 50],
		LHAND: [3, 47, 23, 61],
		LFINGER: [3, 47, 23, 61],
		RARM: [71, 18, 100, 50],
		RHAND: [79, 47, 100, 61],
		RFINGER: [79, 47, 100, 61],
		LLEG: [33, 55, 52, 92],
		LFOOT: [32, 90, 51, 100],
		RLEG: [52, 55, 71, 92],
		RFOOT: [52, 90, 72, 100],
	};
	const W = 100;
	const H = 100;
	const RANK: Record<Severity, number> = { minor: 0, major: 1, critical: 2 };

	const parts = $derived.by(() => {
		const worst = new Map<BodyPart, Severity>();
		for (const inj of healthState.injuries) {
			if (!inj.part) continue;
			const prev = worst.get(inj.part);
			if (!prev || RANK[inj.severity] > RANK[prev]) worst.set(inj.part, inj.severity);
		}
		return [...worst.entries()];
	});

	function clip([l, t, r, b]: [number, number, number, number]): string {
		const p = (v: number, total: number) => `${((v / total) * 100).toFixed(2)}%`;
		return `inset(${p(t, H)} ${p(W - r, W)} ${p(H - b, H)} ${p(l, W)})`;
	}
</script>

{#each parts as [part, severity] (part)}
	<div class="glow" style:--c={SEVERITY_COLORS[severity].solid}>
		<div class="tint" style:clip-path={clip(BOXES[part])} style:mask-image={`url(${silhouette})`} style:-webkit-mask-image={`url(${silhouette})`}></div>
	</div>
{/each}

<style>
	.glow {
		position: absolute;
		inset: 0;
		pointer-events: none;
		filter: drop-shadow(0 0 calc(var(--u) * 6) var(--c)) drop-shadow(0 0 calc(var(--u) * 2) var(--c));
	}

	.tint {
		position: absolute;
		inset: 0;
		background: var(--c);
		mask-size: 100% 100%;
		-webkit-mask-size: 100% 100%;
		transition: clip-path 200ms ease;
	}
</style>
