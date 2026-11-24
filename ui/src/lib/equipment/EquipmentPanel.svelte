<!-- Character silhouette flanked by the six equipment slots (left: backpack/armor/phone, right: parachute/wallet/key) -->
<script lang="ts">
	import { EQUIPMENT_SLOTS } from '../store/inventory.svelte';
	import { healthState } from '../health/health.svelte';
	import silhouette from '../../assets/images/silhouette-body.svg';
	import EquipmentSlot from './EquipmentSlot.svelte';
	import BodyHighlight from '../health/BodyHighlight.svelte';

	const left = EQUIPMENT_SLOTS.slice(0, 3);
	const right = EQUIPMENT_SLOTS.slice(3);
</script>

<div class="equipment" data-panel>
	<div class="column left">
		{#each left as slot (slot.id)}
			<EquipmentSlot def={slot} />
		{/each}
	</div>
	<div class="column right">
		{#each right as slot (slot.id)}
			<EquipmentSlot def={slot} />
		{/each}
	</div>
	<div class="silhouette">
		<div class="art">
			<img src={silhouette} alt="" width="203.705" height="477.704" />
			<!-- injured parts glow over the outline on every tab -->
			{#if healthState.available}
				<BodyHighlight />
			{/if}
		</div>
	</div>
</div>

<style>
	/* Figma "Container" 132:3340, 499x514: slot columns at y45 (x0 and x351), the 202x476 outline
	   laid over them at x138 y19. Every value is Figma px ÷ 1.0547 */
	.equipment {
		position: relative;
		width: calc(var(--u) * 473.1);
		height: calc(var(--u) * 487.3);
		pointer-events: auto;
	}

	.column {
		position: absolute;
		top: calc(var(--u) * 42.7);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: calc(var(--u) * 52.2);
	}

	.column.left {
		left: 0;
		width: calc(var(--u) * 116.6);
	}

	.column.right {
		left: calc(var(--u) * 332.8);
		width: calc(var(--u) * 140.3);
		height: calc(var(--u) * 402);
	}

	.silhouette {
		position: absolute;
		left: calc(var(--u) * 130.8);
		top: calc(var(--u) * 18);
		width: calc(var(--u) * 191.5);
		height: calc(var(--u) * 451.3);
		pointer-events: none;
	}

	/* the outline's stroke bleeds slightly past its frame, as in the design */
	.art {
		position: absolute;
		inset: -0.18% -0.42%;
	}

	.art img {
		display: block;
		width: 100%;
		height: 100%;
	}
</style>
