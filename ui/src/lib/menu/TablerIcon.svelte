<script lang="ts">
	import { TABLER, type TablerName } from './icons';

	let { name, class: cls = '' }: { name: TablerName; class?: string } = $props();
</script>

<svg class={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
	{#each TABLER[name] as d (d)}
		<path {d} />
	{/each}
</svg>
