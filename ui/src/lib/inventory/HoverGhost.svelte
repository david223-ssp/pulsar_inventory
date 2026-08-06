<!-- Cursor-following dragged-item visual -->
<script lang="ts">
	import { dragState, itemDataFor, secondaryPane } from '../store/inventory.svelte';
	import { getItemImage, getItemLabel } from '../util/itemImage';
	import { calcDurability } from '../util/durability';
	import { formatShopPrice, getRarityBorderColor } from '../../config';

	let x = $state(0);
	let y = $state(0);

	$effect(() => {
		function onMove(e: MouseEvent) {
			x = e.clientX;
			y = e.clientY;
		}
		window.addEventListener('mousemove', onMove);
		return () => window.removeEventListener('mousemove', onMove);
	});

	const held = $derived(dragState.held);
	const itemData = $derived(held ? itemDataFor(held.Name) : null);
	const durability = $derived(held && itemData ? calcDurability(held.CreateDate, itemData.durability) : null);
	const broken = $derived(durability != null && durability <= 0);
	const DURABILITY_TICKS = 5;
	const durabilityFilled = $derived(durability != null ? Math.max(1, Math.ceil((durability / 100) * DURABILITY_TICKS)) : 0);
	const durabilityColor = $derived(durability == null ? '' : durability >= 60 ? 'var(--color-success)' : durability >= 25 ? 'var(--color-warning)' : 'var(--color-error)');

	const isShopItem = $derived(dragState.origin?.pane === 'secondary' && !!secondaryPane.shop);
	const unitPrice = $derived(held ? (held.Price ?? itemData?.price ?? 0) : 0);
	const isFree = $derived(isShopItem && (!!secondaryPane.free || !unitPrice));
</script>

{#if held && itemData}
	<div class="ghost" style:top={`${y}px`} style:left={`${x}px`}>
		<div class="slot" class:broken style:border-color={broken ? undefined : getRarityBorderColor(itemData.rarity)}>
			<div class="image"><img src={getItemImage(held, itemData)} alt="" /></div>
			<div class="label" class:with-price={isShopItem}>
				<span class="name">{getItemLabel(held, itemData)}</span>
				{#if isShopItem}
					<span class="price" class:free={isFree}>{isFree ? 'Free' : formatShopPrice(unitPrice)}</span>
				{/if}
			</div>
			{#if held.Count > 1}
				<div class="count">{held.Count}</div>
			{/if}
			{#if itemData.durability && held.CreateDate && !broken && durability != null}
				<div class="durability-meter" style:color={durabilityColor}>
					{#each { length: DURABILITY_TICKS } as _, i (i)}
						<span class="tick" class:filled={i < durabilityFilled}></span>
					{/each}
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	.ghost {
		position: fixed;
		top: 0;
		left: 0;
		pointer-events: none;
		z-index: 200;
		transform: translate(-50%, -50%);
		filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.4));
	}

	.slot {
		position: relative;
		width: 4.6vw;
		height: 9.5vh;
		min-width: 58px;
		min-height: 58px;
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 6px;
		background: rgba(32, 34, 45, 0.9);
		box-shadow: 0 10px 24px rgba(0, 0, 0, 0.45);
		overflow: hidden;
	}

	.slot.broken {
		background: rgba(220, 53, 69, 0.2);
		border-color: rgba(220, 53, 69, 0.4);
	}

	.image {
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.image img {
		max-width: 65%;
		max-height: 65%;
		object-fit: contain;
	}

	.label {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		padding: 0.4vh 0.2vw;
		background: linear-gradient(to top, rgba(0, 0, 0, 0.78) 0%, rgba(0, 0, 0, 0) 100%);
	}

	.label.with-price {
		padding-top: 0.9vh;
	}

	.label .name {
		width: 100%;
		font-size: 0.85vmin;
		font-weight: 500;
		color: var(--color-text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.label .price {
		font-size: 0.78vmin;
		font-weight: 600;
		color: var(--color-success);
	}

	.label .price.free {
		color: var(--color-primary-light);
	}

	.count {
		position: absolute;
		top: 0.4vh;
		right: 0.3vw;
		padding: 0.15vh 0.35vw;
		font-size: 0.9vmin;
		font-weight: 600;
		color: var(--color-text);
		background: rgba(0, 0, 0, 0.5);
		border-radius: 4px;
	}

	.durability-meter {
		position: absolute;
		bottom: 2.6vh;
		left: 0;
		width: 100%;
		display: flex;
		gap: 1.5px;
		padding: 0 0.3vw;
	}

	.tick {
		flex: 1;
		height: 3px;
		border-radius: 1px;
		background: rgba(0, 0, 0, 0.35);
	}

	.tick.filled {
		background: currentColor;
	}
</style>
