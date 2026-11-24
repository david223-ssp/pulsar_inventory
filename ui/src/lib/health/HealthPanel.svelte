<!-- Health & Injuries tab, under the equipment column: "INJURIES" heading, rule and the injury cards -->
<script lang="ts">
	import { healthState, healInjury, diagnosis, partLabel, SEVERITY_LABELS, type Injury } from './health.svelte';
	import { itemDataFor, playerPane } from '../store/inventory.svelte';
	import { getItemImage } from '../util/itemImage';
	import { SEVERITY_COLORS } from './severity';
	import dropletIcon from '../../assets/images/icon-droplet.svg';

	// the medical item "Heal Injury" will use: the first of Lua's list the player is carrying
	const healItem = $derived(healthState.healItems.find((name) => playerPane.inventory.some((i) => i?.Name === name && i.Count > 0)) ?? null);
	const previewItem = $derived(healItem ?? healthState.healItems[0] ?? null);
	const previewData = $derived(previewItem ? itemDataFor(previewItem) : null);

	function heal(injury: Injury) {
		if (healItem) healInjury(injury);
	}
</script>

<div class="injuries" data-panel>
	<h2 class="heading">INJURIES</h2>
	<div class="rule"></div>

	<div class="list">
		{#if !healthState.available}
			<p class="empty">Health data is unavailable right now.</p>
		{:else}
			{#each healthState.injuries as injury (injury.id)}
				{@const c = SEVERITY_COLORS[injury.severity]}
				<article class="injury" style:--c={c.solid} style:--c-bg={c.bg} style:--c-border={c.border}>
					<div class="meta">
						<span class="part">{partLabel(injury).toUpperCase()}</span>
						<span class="severity">{SEVERITY_LABELS[injury.severity].toUpperCase()} INJURY</span>
						{#if injury.bleeding}
							<span class="bleeding"><span class="droplet" style:mask-image={`url(${dropletIcon})`} style:-webkit-mask-image={`url(${dropletIcon})`}></span>BLEEDING</span>
						{/if}
					</div>
					<span class="title">{diagnosis(injury).toUpperCase()}</span>
					<span class="heal-label">HEAL INJURY</span>
					<button
						type="button"
						class="heal"
						disabled={!healItem}
						onclick={() => heal(injury)}
						title={healItem ? `Use ${previewData?.label ?? healItem}` : 'No medical items'}
						aria-label={`Heal ${partLabel(injury)}`}
					>
						{#if previewItem && previewData}
							<img src={getItemImage(null, previewData)} alt="" />
						{/if}
					</button>
				</article>
			{:else}
				<p class="empty">No injuries.</p>
			{/each}
		{/if}
	</div>
</div>

<style>
	/* Figma: heading at y651, 451-wide rule at y685, 450x108 cards from y708 spaced 121 apart (all ÷1.0547 into u) */
	.injuries {
		position: relative;
		width: calc(var(--u) * 427.6);
		height: 100%;
		font-family: var(--font-tabs);
		font-weight: 700;
		color: var(--health-text);
		pointer-events: auto;
	}

	.heading {
		position: absolute;
		top: 0;
		left: calc(var(--u) * 3.8);
		margin: 0;
		font-size: calc(var(--u) * 22.3);
		font-weight: 700;
		line-height: normal;
	}

	.rule {
		position: absolute;
		top: calc(var(--u) * 32.2);
		left: 0;
		width: 100%;
		height: calc(var(--u) * 1);
		background: var(--health-rule);
	}

	.list {
		position: absolute;
		top: calc(var(--u) * 54);
		left: calc(var(--u) * 0.9);
		right: 0;
		bottom: 0;
		display: flex;
		flex-direction: column;
		gap: calc(var(--u) * 12.3);
		overflow-y: auto;
		scrollbar-width: none;
	}

	.list::-webkit-scrollbar {
		display: none;
	}

	.injury {
		position: relative;
		flex-shrink: 0;
		height: calc(var(--u) * 102.4);
		border: calc(var(--u) * 2.03) solid var(--c-border);
		border-radius: calc(var(--u) * 3.04);
		background: var(--c-bg);
		overflow: hidden;
	}

	/* solid severity strip on the left edge */
	.injury::before {
		content: '';
		position: absolute;
		left: calc(var(--u) * -2.03);
		top: calc(var(--u) * -2.03);
		bottom: calc(var(--u) * -2.03);
		width: calc(var(--u) * 3.04);
		background: var(--c);
	}

	.meta {
		position: absolute;
		left: calc(var(--u) * 19.3);
		top: calc(var(--u) * 25.3);
		display: flex;
		align-items: center;
		gap: calc(var(--u) * 18);
		font-size: calc(var(--u) * 12.16);
		white-space: nowrap;
	}

	.severity,
	.bleeding {
		color: var(--c);
	}

	.bleeding {
		display: flex;
		align-items: center;
		gap: calc(var(--u) * 7.1);
	}

	.droplet {
		width: calc(var(--u) * 14.19);
		height: calc(var(--u) * 14.19);
		background: currentColor;
		mask-size: contain;
		-webkit-mask-size: contain;
		mask-repeat: no-repeat;
		-webkit-mask-repeat: no-repeat;
	}

	.title {
		position: absolute;
		left: calc(var(--u) * 19.3);
		top: calc(var(--u) * 53.7);
		max-width: calc(var(--u) * 310);
		font-size: calc(var(--u) * 19.26);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.heal-label {
		position: absolute;
		left: calc(var(--u) * 342.2);
		top: calc(var(--u) * 13.1);
		font-size: calc(var(--u) * 12.16);
		white-space: nowrap;
	}

	.heal {
		position: absolute;
		left: calc(var(--u) * 349.7);
		top: calc(var(--u) * 36.8);
		width: calc(var(--u) * 55.75);
		height: calc(var(--u) * 55.75);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		border: calc(var(--u) * 1.01) solid rgba(112, 113, 118, 0.33);
		border-radius: calc(var(--u) * 3.04);
		background: rgba(11, 11, 11, 0.33);
		cursor: pointer;
		transition: border-color 120ms ease, background 120ms ease, transform 120ms ease;
	}

	.heal:hover:not(:disabled) {
		border-color: rgba(238, 238, 239, 0.6);
		background: rgba(11, 11, 11, 0.5);
		transform: translateY(calc(var(--u) * -1));
	}

	.heal:disabled {
		cursor: not-allowed;
		opacity: 0.4;
	}

	.heal img {
		width: calc(var(--u) * 33.45);
		height: calc(var(--u) * 28.38);
		object-fit: contain;
	}

	.empty {
		margin: calc(var(--u) * 8) 0 0 calc(var(--u) * 3);
		font-size: calc(var(--u) * 14.2);
		color: rgba(238, 238, 239, 0.6);
	}
</style>
