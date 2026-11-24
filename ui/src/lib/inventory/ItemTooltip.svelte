<!-- Item tooltip (ox_inventory SlotTooltip layout): eyebrow, name, rarity pips, description, status block.
     Used both as the cursor-following hover tooltip and the external static tooltip -->
<script lang="ts">
	import { catalogState, craftingState, hotbarState } from '../store/inventory.svelte';
	import { getRarityColor, getRarityLabel, getTypeLabel, IGNORED_METADATA_FIELDS, CURRENCY } from '../../config';
	import { parseMetaData } from '../util/metadata';
	import { calcDurability } from '../util/durability';
	import { sanitizeHtml } from '../util/sanitize';
	import { getItemLabel } from '../util/itemImage';
	import { formatWeight } from '../util/weight';
	import { paneKind } from '../menu/paneKind';
	import SegmentedBar from '../shared/SegmentedBar.svelte';
	import type { InventorySlotItem, ItemDefinition, PaneId } from '../types';

	let {
		instance,
		itemData,
		pane,
		shop = false,
		free = false,
		isEligible = false,
		isQualified = false,
	}: { instance: InventorySlotItem; itemData: ItemDefinition; pane?: PaneId; shop?: boolean; free?: boolean; isEligible?: boolean; isQualified?: boolean } = $props();

	const metadata = $derived(parseMetaData(instance.MetaData));
	const durability = $derived(calcDurability(instance.CreateDate, itemData.durability));
	const rarity = $derived(itemData.rarity ?? 1);
	// 5 pips like ox: Common..Epic fill 1-4, Objective and Legendary fill all five
	const tier = $derived(Math.max(1, Math.min(5, rarity >= 5 ? 5 : rarity)));
	const price = $derived(instance.Price ?? itemData.price);
	const weight = $derived(formatWeight((itemData.weight || 0) * instance.Count));

	const visibleMetaKeys = $derived(
		Object.keys(metadata)
			.filter((k) => !IGNORED_METADATA_FIELDS.has(k))
			.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0)),
	);

	const equippedFitment = $derived.by(() => {
		if (!itemData.component || !hotbarState.equipped) return null;
		const equippedName = catalogState.items[hotbarState.equipped.Name]?.name ?? hotbarState.equipped.Name;
		return !!itemData.component.strings[equippedName];
	});

	const schematicTeaches = $derived.by(() => {
		if (!itemData.schematic) return null;
		const s = craftingState.schematics[itemData.schematic];
		if (!s) return null;
		const resultItem = catalogState.items[s.result.name];
		if (!resultItem) return null;
		return `x${s.result.count} ${resultItem.label}`;
	});

	const needsLicense = $derived(shop && itemData.type === 2 && !!itemData.requiresLicense);
	const needsQualification = $derived(shop && !!itemData.qualification);
	const hasQuality = $derived(instance.Quality != null && instance.Quality > 0);

	const hasStatus = $derived(
		durability != null ||
			hasQuality ||
			(shop && !free && price > 0) ||
			needsLicense ||
			needsQualification ||
			equippedFitment != null ||
			!!schematicTeaches ||
			instance.id != null ||
			visibleMetaKeys.length > 0 ||
			metadata.ammo != null,
	);

	function durabilityTone(p: number): 'accent' | 'warning' | 'danger' {
		return p >= 50 ? 'accent' : p >= 20 ? 'warning' : 'danger';
	}

	function formatDate(value: unknown): string {
		if (typeof value !== 'number' && typeof value !== 'string') return String(value);
		const d = new Date(value);
		return Number.isNaN(d.getTime()) ? String(value) : d.toISOString().slice(0, 10).replace(/-/g, '/');
	}

	function formatRelative(unixSeconds: number): string {
		const diffMs = unixSeconds * 1000 - Date.now();
		const mins = Math.round(Math.abs(diffMs) / 60000);
		if (mins < 1) return 'now';
		if (mins < 60) return diffMs > 0 ? `in ${mins}m` : `${mins}m ago`;
		const hours = Math.round(mins / 60);
		if (hours < 24) return diffMs > 0 ? `in ${hours}h` : `${hours}h ago`;
		const days = Math.round(hours / 24);
		return diffMs > 0 ? `in ${days}d` : `${days}d ago`;
	}

	// label + value for the plain metadata keys; list-shaped ones render below
	const META_LABELS: Record<string, string> = {
		SerialNumber: 'Serial',
		ScratchedSerialNumber: 'Serial',
		StateID: 'State ID',
		PassportID: 'Passport ID',
		DOB: 'Date of Birth',
		EvidenceAmmoType: 'Ammo Type',
		EvidenceId: 'Evidence ID',
		EvidenceDegraded: 'Degraded',
		VaultCode: 'Vault Code',
		BranchName: 'Fleeca Branch',
		Finished: 'Ready',
		CryptoCoin: 'Currency',
		MethTable: 'Table ID',
	};
	const MONO = new Set(['SerialNumber', 'StateID', 'PassportID', 'EvidenceId', 'VaultCode', 'MethTable']);
</script>

<div class="tooltip-wrapper" style:--rarity={getRarityColor(rarity)} class:common={rarity <= 1}>
	<div class="eyebrow">
		<span class="kind">{getTypeLabel(itemData.type)}</span>
		<span class="dim-slash">/</span>
		<span class="context">{paneKind(pane)}</span>
		{#if weight}<span class="meta">{weight}</span>{/if}
	</div>

	<div class="name">
		<span class="slash"></span>
		<span class="label">{getItemLabel(instance, itemData)}</span>
		{#if instance.Count > 1}<span class="count">×{instance.Count.toLocaleString('en-us')}</span>{/if}
	</div>

	<div class="rarity">
		<span class="rarity-label">{getRarityLabel(rarity)}</span>
		<span class="pips">
			{#each [1, 2, 3, 4, 5] as i (i)}
				<span class:on={i <= tier}></span>
			{/each}
		</span>
		{#if itemData.isUsable}<span class="usable">Usable</span>{/if}
	</div>

	{#if itemData.description}
		<!-- eslint-disable-next-line svelte/no-at-html-tags -->
		<div class="description">{@html sanitizeHtml(itemData.description)}</div>
	{/if}

	{#if hasStatus}
		<div class="status">
			{#if durability != null}
				<div class="durability">
					<div class="row">
						<span class="field-label">Durability</span>
						<span class="value mono" class:danger={durability <= 0}>{durability > 0 ? `${String(Math.trunc(durability)).padStart(2, '0')}%` : 'Broken'}</span>
					</div>
					<SegmentedBar percent={Math.max(0, durability)} segments={20} tone={durabilityTone(durability)} />
				</div>
			{/if}
			{#if shop && !free && price > 0}
				<div class="row"><span class="field-label">Price</span><span class="value mono">{CURRENCY.format(price)}</span></div>
			{/if}
			{#if needsLicense}
				<div class="row"><span class="field-label">Weapons Permit</span><span class="value" class:ok={isEligible} class:danger={!isEligible}>{isEligible ? 'Valid' : 'Required'}</span></div>
			{/if}
			{#if needsQualification}
				<div class="row"><span class="field-label">Qualification</span><span class="value" class:ok={isQualified} class:danger={!isQualified}>{isQualified ? 'Met' : 'Required'}</span></div>
			{/if}
			{#if hasQuality}
				<div class="row"><span class="field-label">Quality</span><span class="value mono">{instance.Quality}%</span></div>
			{/if}
			{#if metadata.ammo != null}
				<div class="row"><span class="field-label">Ammo</span><span class="value mono">{metadata.ammo}</span></div>
			{/if}
			{#if equippedFitment != null}
				<div class="row"><span class="field-label">Equipped Weapon</span><span class="value" class:ok={equippedFitment} class:danger={!equippedFitment}>{equippedFitment ? 'Fits' : "Doesn't Fit"}</span></div>
			{/if}
			{#if schematicTeaches}
				<div class="row"><span class="field-label">Teaches</span><span class="value">{schematicTeaches}</span></div>
			{/if}
			{#if instance.id != null}
				<div class="row"><span class="field-label">ID</span><span class="value mono">{instance.id}</span></div>
			{/if}

			{#each visibleMetaKeys as key (key)}
				{@const value = metadata[key]}
				{#if key === 'ChopList'}
					{@const chopList = (value as { name: string; hv?: boolean }[]) ?? []}
					<div class="row"><span class="field-label">Request List</span><span class="value">{chopList.length > 0 ? '' : 'No Vehicles'}</span></div>
					{#if chopList.length > 0}
						<ul class="list">
							{#each [...chopList].sort((a, b) => (b.hv ? 1 : 0) - (a.hv ? 1 : 0)) as chop, i (i)}
								<li class:hv={chop.hv}>{chop.name}</li>
							{/each}
						</ul>
					{/if}
				{:else if key === 'WeaponComponents'}
					{@const components = Object.entries((value as Record<string, { item: string }>) ?? {}).filter(([, a]) => catalogState.items[a.item])}
					{#if components.length > 0}
						<div class="row"><span class="field-label">Components</span><span class="value">{components.map(([, a]) => catalogState.items[a.item].label).join(', ')}</span></div>
					{/if}
				{:else if key === 'AccessCodes'}
					{#each (value as { label: string; code: string }[]) ?? [] as code, i (i)}
						<div class="row"><span class="field-label">{code.label}</span><span class="value mono">{code.code}</span></div>
					{/each}
				{:else if key === 'EvidenceColor'}
					{@const c = value as { r: number; g: number; b: number }}
					<div class="row"><span class="field-label">Fragment Color</span><span class="value" style:color={`rgb(${c.r} ${c.g} ${c.b})`}>R {c.r} · G {c.g} · B {c.b}</span></div>
				{:else if key === 'EvidenceBloodPool'}
					<div class="row"><span class="field-label">Blood</span><span class="value">{value ? 'Pool of Blood' : 'Drops of Blood'}</span></div>
				{:else if key === 'CustomItemText'}
					<div class="row text"><span class="value">{value}</span></div>
				{:else}
					<div class="row">
						<span class="field-label">{META_LABELS[key] ?? key}</span>
						<span class="value" class:mono={MONO.has(key)}>
							{#if key === 'ScratchedSerialNumber'}&lt;scratched off&gt;
							{:else if key === 'DOB'}{formatDate(value)}
							{:else if key === 'EvidenceDegraded'}{value ? 'Yes' : 'No'}
							{:else if key === 'Finished'}{formatRelative(value as number)}
							{:else if key === 'CryptoCoin'}{CURRENCY.format(value as number)}
							{:else}{String(value)}{/if}
						</span>
					</div>
				{/if}
			{/each}
		</div>
	{/if}
</div>

<style>
	/* ox_inventory's glass tooltip; --r = 1px of the ox design (1080p) */
	.tooltip-wrapper {
		position: relative;
		pointer-events: none;
		display: flex;
		flex-direction: column;
		gap: calc(var(--r) * 9);
		box-sizing: border-box;
		width: calc(var(--r) * 256);
		padding: calc(var(--r) * 12) calc(var(--r) * 14) calc(var(--r) * 12) calc(var(--r) * 17);
		border-radius: calc(var(--r) * 14);
		background:
			linear-gradient(155deg, rgba(255, 255, 255, 0.13), rgba(255, 255, 255, 0.04) 40%, rgba(255, 255, 255, 0.015) 100%),
			rgba(22, 26, 34, 0.9);
		box-shadow:
			inset 0 1px 0 rgba(255, 255, 255, 0.16),
			0 calc(var(--r) * 20) calc(var(--r) * 50) rgba(0, 0, 0, 0.5),
			0 calc(var(--r) * 2) calc(var(--r) * 6) rgba(0, 0, 0, 0.25);
		font-family: var(--font-body);
		color: #e4e4e7;
		overflow: hidden;
	}

	/* rarity tint from the top-left corner (faded with opacity so it works with any CSS color) */
	.tooltip-wrapper::after {
		content: '';
		position: absolute;
		inset: 0;
		background: radial-gradient(ellipse 90% 60% at 0% 0%, var(--rarity), transparent 70%);
		opacity: 0.24;
		pointer-events: none;
	}

	.tooltip-wrapper.common::after {
		display: none;
	}

	/* rim that catches light at the top-left */
	.tooltip-wrapper::before {
		content: '';
		position: absolute;
		inset: 0;
		padding: 1px;
		border-radius: inherit;
		background: linear-gradient(150deg, rgba(255, 255, 255, 0.32), rgba(255, 255, 255, 0.08) 35%, rgba(255, 255, 255, 0.04) 65%, rgba(255, 255, 255, 0.14));
		-webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
		-webkit-mask-composite: xor;
		mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
		mask-composite: exclude;
		pointer-events: none;
	}

	.tooltip-wrapper > * {
		position: relative;
		z-index: 1;
	}

	.field-label {
		font-size: calc(var(--r) * 10);
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.24em;
		line-height: 1;
		color: #71717a;
	}

	.eyebrow {
		display: flex;
		align-items: center;
		gap: calc(var(--r) * 6);
		font-size: calc(var(--r) * 10);
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.24em;
		line-height: 1;
	}

	.kind {
		color: var(--color-primary-light);
		white-space: nowrap;
	}

	.dim-slash {
		color: #52525b;
	}

	.context {
		color: #a1a1aa;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.meta {
		margin-left: auto;
		flex-shrink: 0;
		font-size: calc(var(--r) * 10.5);
		letter-spacing: 0;
		text-transform: none;
		font-variant-numeric: tabular-nums;
		color: #71717a;
	}

	.name {
		display: flex;
		align-items: center;
		gap: calc(var(--r) * 9);
		font-size: calc(var(--r) * 18);
		font-weight: 700;
		line-height: 1.05;
		color: #ffffff;
	}

	.slash {
		flex-shrink: 0;
		width: calc(var(--r) * 5);
		height: calc(var(--r) * 16);
		transform: skewX(-14deg);
		background: var(--rarity);
		box-shadow: 0 0 calc(var(--r) * 8) var(--rarity);
	}

	.label {
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.count {
		margin-left: auto;
		flex-shrink: 0;
		font-size: calc(var(--r) * 12);
		font-weight: 600;
		font-variant-numeric: tabular-nums;
		color: #a1a1aa;
	}

	.rarity {
		display: flex;
		align-items: center;
		gap: calc(var(--r) * 10);
		margin-top: calc(var(--r) * -3);
	}

	.rarity-label {
		font-size: calc(var(--r) * 10);
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.24em;
		line-height: 1;
		color: var(--rarity);
	}

	.pips {
		display: flex;
		gap: 2px;
	}

	.pips span {
		width: calc(var(--r) * 10);
		height: calc(var(--r) * 4);
		transform: skewX(-14deg);
		background: rgba(255, 255, 255, 0.1);
	}

	.pips span.on {
		background: var(--rarity);
	}

	.usable {
		margin-left: auto;
		font-size: calc(var(--r) * 10);
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.18em;
		color: var(--color-success);
	}

	.description {
		font-size: calc(var(--r) * 12);
		line-height: 1.45;
		color: #a1a1aa;
	}

	.description :global(p) {
		margin: 0;
	}

	.status {
		display: flex;
		flex-direction: column;
		gap: calc(var(--r) * 8);
		margin: calc(var(--r) * 3) calc(var(--r) * -14) calc(var(--r) * -12) calc(var(--r) * -17);
		padding: calc(var(--r) * 10) calc(var(--r) * 14) calc(var(--r) * 12) calc(var(--r) * 17);
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		background: rgba(255, 255, 255, 0.02);
	}

	.durability {
		display: flex;
		flex-direction: column;
		gap: calc(var(--r) * 6);
	}

	.row {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: calc(var(--r) * 12);
	}

	.row.text .value {
		text-align: left;
	}

	.value {
		font-size: calc(var(--r) * 12);
		color: #e4e4e7;
		text-align: right;
		overflow-wrap: anywhere;
	}

	.value.mono {
		font-size: calc(var(--r) * 11.5);
		font-variant-numeric: tabular-nums;
	}

	.value.ok {
		color: var(--color-success);
	}

	.value.danger {
		color: #f87171;
	}

	.list {
		margin: 0;
		padding-left: calc(var(--r) * 14);
		font-size: calc(var(--r) * 12);
		color: #d4d4d8;
	}

	.list li.hv {
		color: #fcd34d;
	}
</style>
