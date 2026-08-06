<!-- plain CSS spinner -->
<script lang="ts">
	let { text = 'Loading', static: isStatic = false }: { text?: string; static?: boolean } = $props();
</script>

<div class="loader" class:static={isStatic}>
	<div class="spinner"></div>
	<div class="text">{text}</div>
</div>

<style>
	.loader {
		text-align: center;
	}

	.loader.static {
		position: absolute;
		inset: 0;
		margin: auto;
		width: fit-content;
		height: fit-content;
	}

	.spinner {
		width: 3vh;
		height: 3vh;
		margin: 0 auto 0.8vh;
		border: 3px solid rgba(139, 92, 246, 0.2);
		border-top-color: var(--color-primary);
		border-radius: 50%;
		animation: spin 800ms linear infinite;
	}

	.text {
		font-size: 1.1vmin;
		font-weight: 600;
		color: var(--color-text);
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
</style>
