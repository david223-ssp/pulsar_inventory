<!-- Recipe browser search filters by the resolved output itemss label -->
<script lang="ts">
	import { craftingState, catalogState } from '../store/inventory.svelte';
	import Icon from '../Icon.svelte';
	import RecipeCard from './RecipeCard.svelte';

	let search = $state('');
	let crafting = $state(false);

	const filtered = $derived(
		search === ''
			? craftingState.recipes
			: craftingState.recipes.filter((r) => catalogState.items[r.result.name] && catalogState.items[r.result.name].label.toLowerCase().includes(search.toLowerCase())),
	);
</script>

<div class="screen">
	<label class="search">
		<Icon name="magnifying-glass" size="1.1vmin" />
		<input type="text" placeholder="Search recipes" bind:value={search} disabled={crafting} />
		{#if search}
			<button type="button" class="clear" onclick={() => (search = '')} aria-label="Clear search">
				<Icon name="xmark" size="1vmin" />
			</button>
		{/if}
	</label>

	<div class="recipes">
		{#each filtered as recipe (recipe.id)}
			<RecipeCard {recipe} cooldown={craftingState.cooldowns[recipe.id]} oncraftingchange={(v) => (crafting = v)} />
		{/each}
		{#if filtered.length === 0}
			<div class="empty">No Recipes Found</div>
		{/if}
	</div>
</div>

<style>
	.screen {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		padding: calc(var(--u) * 16);
	}

	.search {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 0.6vw;
		background: rgba(255, 255, 255, 0.05);
		border: var(--border-subtle);
		border-radius: var(--radius);
		padding: 0.9vh 0.8vw;
		color: var(--color-text-muted);
		margin-bottom: 1vh;
	}

	.search input {
		flex: 1;
		background: transparent;
		border: none;
		color: var(--color-text);
		font-family: inherit;
		font-size: 1.15vmin;
	}

	.search input:focus {
		outline: none;
	}

	.clear {
		background: transparent;
		border: none;
		color: var(--color-text-muted);
		cursor: pointer;
		display: flex;
	}

	.recipes {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-wrap: wrap;
		align-content: flex-start;
		gap: 0.6vw;
	}

	.empty {
		width: 100%;
		text-align: center;
		padding: 3vh 0;
		color: var(--color-text-muted);
		font-size: 1.1vmin;
	}
</style>
