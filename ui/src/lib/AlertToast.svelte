<!-- One pickup/loss/use toast, styled like an inventory slot card. Auto-dismiss timing lives in the store -->
<script lang="ts">
	import { fly } from 'svelte/transition';
	import { itemDataFor } from './store/inventory.svelte';
	import { getItemImage, getItemLabel } from './util/itemImage';
	import { getRarityBorderColor } from '../config';
	import Icon from './Icon.svelte';
	import type { ChangeAlert } from './types';

	let { alert }: { alert: ChangeAlert } = $props();

	const itemData = $derived(itemDataFor(alert.item));

	const TYPE_META: Record<string, { icon: string; label: string }> = {
		add: { icon: 'plus', label: 'Added' },
		removed: { icon: 'minus', label: 'Removed' },
		used: { icon: 'circle-check', label: 'Used' },
	};
	const meta = $derived(TYPE_META[alert.type] ?? { icon: 'circle-exclamation', label: alert.type });
</script>

<div class="toast {alert.type}" style:border-color={getRarityBorderColor(itemData.rarity)} transition:fly={{ x: 24, duration: 220 }}>
	<span class="badge type" title={meta.label}><Icon name={meta.icon} size="1.3vmin" /></span>
	{#if alert.count > 0}
		<span class="badge count">{alert.type === 'removed' ? '-' : alert.type === 'add' ? '+' : ''}{alert.count}</span>
	{/if}
	<div class="image"><img src={getItemImage(null, itemData)} alt="" loading="lazy" /></div>
	<div class="label">{getItemLabel(null, itemData)}</div>
</div>

<style>
	.toast {
		position: relative;
		width: 5.6vw;
		min-width: 74px;
		height: 9.6vh;
		min-height: 84px;
		pointer-events: none;
		background: rgba(20, 18, 28, 0.92);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 2px;
		box-shadow: 0 10px 28px rgba(0, 0, 0, 0.45);
		overflow: hidden;
	}

	.image {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.image img {
		max-width: 62%;
		max-height: 62%;
		object-fit: contain;
		filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.5));
	}

	.label {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		text-align: center;
		padding: 0.6vh 0.3vw;
		font-size: 0.92vmin;
		font-weight: 500;
		color: var(--color-text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		background: linear-gradient(to top, rgba(0, 0, 0, 0.75) 0%, rgba(0, 0, 0, 0) 100%);
	}

	.badge {
		position: absolute;
		top: 0.5vh;
		z-index: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 3px;
		background: rgba(0, 0, 0, 0.55);
	}

	/* Solid fill, not a pale tint, so it reads at a glance */
	.badge.type {
		left: 0;
		top: 0;
		width: 3.1vh;
		height: 3.1vh;
		border-radius: 0 0 3px 0;
		box-shadow: 2px 2px 6px rgba(0, 0, 0, 0.35);
	}

	.toast.add .badge.type {
		color: #0f1c14;
		background: var(--color-success);
	}

	.toast.removed .badge.type {
		color: #2a0c0d;
		background: var(--color-error);
	}

	.toast.used .badge.type {
		color: #0c1a26;
		background: var(--color-info);
	}

	.badge.count {
		right: 0.4vw;
		padding: 0.15vh 0.4vw;
		font-size: 1vmin;
		font-weight: 700;
		font-variant-numeric: tabular-nums;
		color: var(--color-text);
	}

	.toast.add .badge.count {
		color: var(--color-success);
	}

	.toast.removed .badge.count {
		color: var(--color-error);
	}
</style>
