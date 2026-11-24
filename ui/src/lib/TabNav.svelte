<!-- Top pill navigation: Q / E cycle through the tabs, clicking a label jumps to it -->
<script lang="ts">
	import { onMount } from 'svelte';
	import { TABS, cycleTab, setTab, uiState } from './store/inventory.svelte';
	import { Nui } from './nui';
	import { healthState } from './health/health.svelte';

	// label box widths from the design, so every label sits exactly where it was drawn
	const WIDTHS: Record<string, number> = { inventory: 118.03, health: 183.48, crafting: 107.3, experience: 128.76 };

	function go(dir: 1 | -1) {
		cycleTab(dir);
		void Nui.frontEndSound('UPDOWN');
	}

	onMount(() => {
		const onKey = (e: KeyboardEvent) => {
			if (uiState.hidden || e.repeat) return;
			const t = e.target as HTMLElement | null;
			if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA')) return;
			const k = e.key.toLowerCase();
			if (k === 'q') go(-1);
			else if (k === 'e') go(1);
		};
		window.addEventListener('keydown', onKey);
		return () => window.removeEventListener('keydown', onKey);
	});
</script>

<nav class="tabs" data-panel>
	<button type="button" class="shortcut left" onclick={() => go(-1)} aria-label="Previous tab">Q</button>
	<div class="labels" role="tablist">
		{#each TABS as tab (tab.id)}
			<button type="button" role="tab" class="tab" class:active={uiState.tab === tab.id} class:unavailable={(tab.id === 'health' && !healthState.available) || tab.id === 'experience'} aria-selected={uiState.tab === tab.id} style:width={`calc(var(--u) * ${WIDTHS[tab.id]})`} onclick={() => setTab(tab.id)}>
				{tab.label}
			</button>
		{/each}
	</div>
	<button type="button" class="shortcut right" onclick={() => go(1)} aria-label="Next tab">E</button>
</nav>

<style>
	.tabs {
		position: relative;
		width: calc(var(--u) * 684.16);
		height: calc(var(--u) * 48.105);
		border: calc(var(--u) * 1) solid var(--glass-border);
		border-radius: calc(var(--u) * 36);
		background: var(--tab-bg);
		box-shadow: inset 0 calc(var(--u) * 4) calc(var(--u) * 4) 0 rgba(179, 157, 255, 0.25);
		font-family: var(--font-tabs);
		font-weight: 700;
		pointer-events: auto;
	}

	button {
		background: transparent;
		border: none;
		padding: 0;
		font: inherit;
		cursor: pointer;
	}

	.shortcut {
		position: absolute;
		top: calc(var(--u) * -1);
		width: calc(var(--u) * 45.967);
		height: calc(var(--u) * 45.967);
		font-size: calc(var(--u) * 17.104);
		line-height: 1;
		color: var(--color-primary-light);
		text-align: left;
		transition: color 120ms ease;
	}

	.shortcut.left {
		left: calc(var(--u) * -1);
		padding-left: calc(var(--u) * 11.08);
	}

	.shortcut.right {
		left: calc(var(--u) * 633.08);
		padding-left: calc(var(--u) * 23);
	}

	.shortcut:hover {
		color: var(--color-primary-glow);
	}

	.labels {
		position: absolute;
		left: calc(var(--u) * 70.53);
		top: calc(var(--u) * 12.47);
		display: flex;
		gap: calc(var(--u) * 7.5);
	}

	.tab {
		font-size: calc(var(--u) * 18);
		line-height: calc(var(--u) * 22);
		text-align: left;
		white-space: nowrap;
		color: var(--tab-text);
		transition: color 120ms ease;
	}

	.tab:hover {
		color: #ffffff;
	}

	.tab.active {
		color: var(--color-primary-light);
	}

	/* no data source behind it: still reachable, but visibly not live */
	.tab.unavailable {
		opacity: 0.45;
	}
</style>
