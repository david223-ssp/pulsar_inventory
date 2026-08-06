<!-- Top-level shell: hotbar, alerts, main panel, hover/static tooltips -->
<script lang="ts">
	import { fade } from 'svelte/transition';
	import { catalogState, hideSecondaryInventory, hoverTooltipState, itemDataFor, resetInventoryView, staticTooltipState, uiState } from './store/inventory.svelte';
	import Hotbar from './Hotbar.svelte';
	import ChangeAlerts from './ChangeAlerts.svelte';
	import AppScreen from './AppScreen.svelte';
	import InventoryScreen from './inventory/InventoryScreen.svelte';
	import HoverGhost from './inventory/HoverGhost.svelte';
	import ItemTooltip from './inventory/ItemTooltip.svelte';

	function onHideComplete() {
		hideSecondaryInventory();
		resetInventoryView();
	}

	const staticItemData = $derived(staticTooltipState.item ? itemDataFor(staticTooltipState.item.Name) : null);

	// Measured/placed here (fixed to viewport); flips above/below and clamps to stay on-screen
	let hoverTooltipEl = $state<HTMLDivElement | undefined>(undefined);
	let hoverTooltipPos = $state<{ top: number; left: number } | null>(null);

	$effect(() => {
		const info = hoverTooltipState.info;
		if (!info) {
			hoverTooltipPos = null;
			return;
		}
		if (!hoverTooltipEl) return;

		const margin = 10;
		const th = hoverTooltipEl.offsetHeight;
		const tw = hoverTooltipEl.offsetWidth;
		const spaceAbove = info.rect.top;
		const spaceBelow = window.innerHeight - info.rect.bottom;

		const top = spaceAbove >= th + margin || spaceAbove >= spaceBelow ? info.rect.top - th - margin : info.rect.bottom + margin;
		const left = info.rect.left + info.rect.width / 2 - tw / 2;

		hoverTooltipPos = {
			top: Math.max(margin, Math.min(top, window.innerHeight - th - margin)),
			left: Math.max(margin, Math.min(left, window.innerWidth - tw - margin)),
		};
	});
</script>

<Hotbar />
<ChangeAlerts />

{#if catalogState.itemsLoaded && staticTooltipState.item && staticItemData}
	<div class="static-tooltip">
		<ItemTooltip instance={staticTooltipState.item} itemData={staticItemData} />
	</div>
{/if}

{#if catalogState.itemsLoaded && hoverTooltipState.info}
	<div
		class="hover-tooltip"
		bind:this={hoverTooltipEl}
		style:top={hoverTooltipPos ? `${hoverTooltipPos.top}px` : '-9999px'}
		style:left={hoverTooltipPos ? `${hoverTooltipPos.left}px` : '-9999px'}
		style:visibility={hoverTooltipPos ? 'visible' : 'hidden'}
	>
		<ItemTooltip
			instance={hoverTooltipState.info.item}
			itemData={hoverTooltipState.info.itemData}
			shop={hoverTooltipState.info.shop}
			free={hoverTooltipState.info.free}
			isEligible={hoverTooltipState.info.isEligible}
			isQualified={hoverTooltipState.info.isQualified}
		/>
	</div>
{/if}

{#if !uiState.hidden}
	<div class="fade-wrap" transition:fade={{ duration: 180 }} onoutroend={onHideComplete}>
		<AppScreen>
			<InventoryScreen />
		</AppScreen>
		<HoverGhost />
	</div>
{/if}

<style>
	.fade-wrap {
		position: absolute;
		inset: 0;
	}

	.static-tooltip {
		position: absolute;
		top: 3vh;
		left: 50%;
		transform: translateX(-50%);
		z-index: 50;
		pointer-events: none;
	}

	.hover-tooltip {
		position: fixed;
		z-index: 200;
		pointer-events: none;
	}
</style>
