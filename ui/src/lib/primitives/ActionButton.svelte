<!-- Shared themed button -->
<script lang="ts">
	let {
		label,
		onclick,
		disabled = false,
		variant = 'default',
		type = 'button',
	}: { label: string; onclick?: () => void; disabled?: boolean; variant?: 'default' | 'danger' | 'primary'; type?: 'button' | 'submit' } = $props();
</script>

<button {type} class="action" class:danger={variant === 'danger'} class:primary={variant === 'primary'} {disabled} {onclick}>
	{label}
</button>

<style>
	.action {
		background: rgba(232, 232, 236, 0.05);
		border: var(--border-subtle);
		border-radius: var(--radius);
		color: var(--color-text);
		font-family: inherit;
		font-size: 1.05vmin;
		font-weight: 600;
		padding: 0.9vh 1.2vw;
		cursor: pointer;
		transition: color 120ms ease, border-color 120ms ease, background 120ms ease;
	}

	.action:hover:not(:disabled) {
		border-color: rgba(139, 92, 246, 0.5);
		background: rgba(139, 92, 246, 0.14);
		color: var(--color-primary-light);
	}

	.action.primary {
		border-color: rgba(139, 92, 246, 0.5);
		background: rgba(139, 92, 246, 0.12);
		color: var(--color-primary-light);
	}

	.action.primary:hover:not(:disabled) {
		background: rgba(139, 92, 246, 0.2);
	}

	.action.danger:hover:not(:disabled) {
		border-color: rgba(229, 72, 77, 0.5);
		background: rgba(229, 72, 77, 0.14);
		color: var(--color-error);
	}

	.action:disabled {
		opacity: 0.35;
		pointer-events: none;
	}
</style>
