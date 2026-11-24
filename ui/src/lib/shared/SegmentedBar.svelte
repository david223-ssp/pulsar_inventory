<!-- Row of skewed segments (durability etc.), never a smooth rounded bar -->
<script lang="ts">
	let { percent, segments = 20, tone = 'accent' }: { percent: number; segments?: number; tone?: 'accent' | 'warning' | 'danger' } = $props();

	const clamped = $derived(Math.max(0, Math.min(100, percent)));
	const filled = $derived(clamped > 0 ? Math.max(1, Math.round((clamped / 100) * segments)) : 0);
</script>

<div class="segmented-bar" data-tone={tone}>
	{#each Array.from({ length: segments }, (_, i) => i) as i (i)}
		<span class="segment" class:filled={i < filled}></span>
	{/each}
</div>

<style>
	.segmented-bar {
		display: flex;
		gap: 3px;
		height: calc(var(--r) * 6);
	}

	.segment {
		flex: 1;
		transform: skewX(-14deg);
		background: rgba(255, 255, 255, 0.1);
		transition: background-color 200ms ease-out;
	}

	.segment.filled {
		background: #d4d4d8;
	}

	[data-tone='accent'] .segment.filled {
		background: var(--color-primary-light);
	}

	[data-tone='warning'] .segment.filled {
		background: #fcd34d;
	}

	[data-tone='danger'] .segment.filled {
		background: #ef4444;
	}
</style>
