<!-- Single shared item tooltip, used both anchored (hover) and as the external static tooltip -->
<script lang="ts">
	import { catalogState, craftingState, hotbarState } from '../store/inventory.svelte';
	import { getRarityColor, getRarityLabel, getTypeLabel, IGNORED_METADATA_FIELDS, CURRENCY } from '../../config';
	import { parseMetaData } from '../util/metadata';
	import { calcDurability } from '../util/durability';
	import { sanitizeHtml } from '../util/sanitize';
	import { getItemLabel } from '../util/itemImage';
	import Icon from '../Icon.svelte';
	import type { InventorySlotItem, ItemDefinition } from '../types';

	let {
		instance,
		itemData,
		shop = false,
		free = false,
		isEligible = false,
		isQualified = false,
	}: { instance: InventorySlotItem; itemData: ItemDefinition; shop?: boolean; free?: boolean; isEligible?: boolean; isQualified?: boolean } = $props();

	const metadata = $derived(parseMetaData(instance.MetaData));
	const durability = $derived(calcDurability(instance.CreateDate, itemData.durability));

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
		return `Crafting x${s.result.count} ${resultItem.label}`;
	});

	// Rounds float-math artifacts (0.8999999999999999) to 2 decimals
	function formatWeight(value: number): string {
		return (Math.round(value * 100) / 100).toString();
	}

	function formatDate(value: unknown): string {
		if (typeof value !== 'number' && typeof value !== 'string') return String(value);
		const d = new Date(value);
		return Number.isNaN(d.getTime()) ? String(value) : d.toISOString().slice(0, 10).replace(/-/g, '/');
	}

	function formatRelative(unixSeconds: number): string {
		const diffMs = unixSeconds * 1000 - Date.now();
		const abs = Math.abs(diffMs);
		const mins = Math.round(abs / 60000);
		if (mins < 1) return 'now';
		if (mins < 60) return diffMs > 0 ? `in ${mins}m` : `${mins}m ago`;
		const hours = Math.round(mins / 60);
		if (hours < 24) return diffMs > 0 ? `in ${hours}h` : `${hours}h ago`;
		const days = Math.round(hours / 24);
		return diffMs > 0 ? `in ${days}d` : `${days}d ago`;
	}
</script>

<div class="tooltip">
	<div class="name" style:color={getRarityColor(itemData.rarity)}>
		{getItemLabel(instance, itemData)}
		{#if shop && !free && (instance.Price ?? itemData.price) > 0}
			<span class="price">{CURRENCY.format(instance.Price ?? itemData.price)}</span>
		{/if}
	</div>
	<div class="type">
		{getRarityLabel(itemData.rarity)}
		{getTypeLabel(itemData.type)}
		{#if itemData.isUsable}<span class="usable"> - Usable</span>{/if}
	</div>

	{#if instance.id != null}
		<div class="row">ID: <span class="value">{instance.id}</span></div>
	{/if}

	{#if itemData.description}
		<!-- eslint-disable-next-line svelte/no-at-html-tags -->
		<div class="description">{@html sanitizeHtml(itemData.description)}</div>
	{/if}

	{#if shop && ((itemData.type === 2 && itemData.requiresLicense) || itemData.qualification)}
		<div class="qualifications">
			{#if itemData.type === 2 && itemData.requiresLicense}
				<div class:elig={isEligible} class:inelig={!isEligible}>
					<Icon name={isEligible ? 'circle-check' : 'xmark'} size="1vmin" />
					Requires Weapons Permit
				</div>
			{/if}
			{#if itemData.qualification}
				<div class:elig={isQualified} class:inelig={!isQualified}>
					<Icon name={isQualified ? 'circle-check' : 'xmark'} size="1vmin" />
					Requires Additional Qualification
				</div>
			{/if}
		</div>
	{/if}

	{#if equippedFitment != null}
		<div class="fitment">
			<b>{equippedFitment ? 'Fits On Currently Equipped Weapon' : 'Does Not Fit On Currently Equipped Weapon'}</b>
		</div>
	{/if}

	{#if schematicTeaches}
		<div class="fitment"><b>Teaches</b>: {schematicTeaches}</div>
	{/if}

	{#if visibleMetaKeys.length > 0}
		<div class="metadata">
			{#each visibleMetaKeys as key (key)}
				{@const value = metadata[key]}
				<div class="meta-row">
					{#if key === 'SerialNumber'}
						<b>Serial Number</b>: {value}
					{:else if key === 'ScratchedSerialNumber'}
						<b>Serial Number</b>: &lt;scratched off&gt;
					{:else if key === 'StateID'}
						<b>State ID</b>: {value}
					{:else if key === 'PassportID'}
						<b>Passport ID</b>: {value}
					{:else if key === 'DOB'}
						<b>Date of Birth</b>: {formatDate(value)}
					{:else if key === 'EvidenceAmmoType'}
						<b>Ammo Type</b>: {value}
					{:else if key === 'EvidenceId'}
						<b>Evidence ID</b>: {value}
					{:else if key === 'EvidenceColor'}
						{@const c = value as { r: number; g: number; b: number }}
						<span style:color={`rgb(${c.r} ${c.g} ${c.b})`}><b>Fragment Color</b>: R: {c.r} G: {c.g} B: {c.b}</span>
					{:else if key === 'EvidenceDegraded'}
						<b>Evidence Degraded</b>: {value ? 'Yes' : 'No'}
					{:else if key === 'EvidenceBloodPool'}
						{value ? 'Pool of Blood' : 'Drops of Blood'}
					{:else if key === 'CustomItemText'}
						{value}
					{:else if key === 'VaultCode'}
						<b>Vault Access Code</b>: {value}
					{:else if key === 'BranchName'}
						<b>Fleeca Branch</b>: {value}
					{:else if key === 'Finished'}
						<b>Ready</b>: {formatRelative(value as number)}
					{:else if key === 'CryptoCoin'}
						<b>Currency</b>: {CURRENCY.format(value as number)}
					{:else if key === 'ChopList'}
						{@const chopList = (value as { name: string; hv?: boolean }[]) ?? []}
						<b>Request List</b>:
						{#if chopList.length > 0}
							<ul class="sub-list">
								{#each [...chopList].sort((a, b) => (b.hv ? 1 : 0) - (a.hv ? 1 : 0)) as chop, i (i)}
									<li>{#if chop.hv}<Icon name="triangle-exclamation" size="0.9vmin" />{/if} {chop.name}</li>
								{/each}
							</ul>
						{:else}
							<b>No Vehicles On Chop List</b>
						{/if}
					{:else if key === 'WeaponComponents'}
						{@const components = (value as Record<string, { item: string }>) ?? {}}
						{#if Object.keys(components).length > 0}
							<b>Weapon Attachments</b>:
							<ul class="sub-list">
								{#each Object.entries(components) as [slot, attach] (slot)}
									{@const attachItem = catalogState.items[attach.item]}
									{#if attachItem}
										<li><b class="capitalize">{slot}</b>: {attachItem.label}</li>
									{/if}
								{/each}
							</ul>
						{/if}
					{:else if key === 'AccessCodes'}
						{@const codes = (value as { label: string; code: string }[]) ?? []}
						{#if codes.length > 0}
							<b>Access Codes</b>:
							<ul class="sub-list">
								{#each codes as code, i (i)}
									<li><b>{code.label}</b>: {code.code}</li>
								{/each}
							</ul>
						{/if}
					{:else if key === 'MethTable'}
						<b>Table ID</b>: {value}
					{:else}
						<b>{key}</b>: {value}
					{/if}
				</div>
			{/each}
		</div>
	{/if}

	<div class="footer">
		<span class="stat">
			Weight: <span class="value">{formatWeight(itemData.weight || 0)} lbs</span>
			{#if instance.Count > 1}<span class="sub">(Total: {formatWeight((itemData.weight || 0) * instance.Count)} lbs)</span>{/if}
		</span>
		<span class="stat">
			Count: <span class="value">{instance.Count}</span>
			{#if itemData.isStackable}<span class="sub">(Max Stack: {itemData.isStackable})</span>{/if}
		</span>
		{#if durability != null}
			<span class="stat">Durability: <span class="value" class:broken-text={durability <= 0}>{durability > 0 ? durability : 'Broken'}</span></span>
		{/if}
		{#if instance.Quality != null && instance.Quality > 0}
			<span class="stat">Quality: <span class="value" class:quality-good={instance.Quality >= 75} class:quality-mid={instance.Quality >= 50 && instance.Quality < 75} class:quality-low={instance.Quality < 50}>{instance.Quality}%</span></span>
		{/if}
	</div>
</div>

<style>
	.tooltip {
		min-width: 15vw;
		max-width: 19vw;
		padding: 1.2vh 1vw;
		background: rgba(15, 17, 21, 0.97);
		border: var(--border-subtle);
		border-radius: 2px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
		font-size: 1vmin;
	}

	.name {
		font-size: 1.5vmin;
		font-weight: 600;
	}

	.price {
		margin-left: 0.5vw;
		font-size: 1vmin;
		color: var(--color-success);
	}

	.type {
		margin-top: 0.3vh;
		font-size: 1.05vmin;
		color: var(--color-text-muted);
	}

	.usable {
		color: var(--color-success);
	}

	.row {
		margin-top: 0.4vh;
		color: var(--color-text-muted);
	}

	.value {
		color: var(--color-text);
	}

	.sub {
		margin-left: 0.3vw;
		color: var(--color-text-muted);
		font-size: 0.85vmin;
	}

	.description {
		margin-top: 0.6vh;
		padding-left: 0.8vw;
		color: var(--color-text-muted);
		font-size: 1.05vmin;
	}

	.qualifications {
		margin-top: 0.5vh;
		padding-top: 0.5vh;
		border-top: var(--border-subtle);
		font-size: 0.95vmin;
	}

	.qualifications > div {
		display: flex;
		align-items: center;
		gap: 0.4vw;
	}

	.elig {
		color: var(--color-success);
	}

	.inelig {
		color: var(--color-error);
	}

	.fitment {
		margin-top: 0.5vh;
		font-size: 0.95vmin;
		color: var(--color-text-muted);
	}

	.metadata {
		margin-top: 0.7vh;
		padding-top: 0.7vh;
		border-top: var(--border-subtle);
		font-size: 0.95vmin;
		color: var(--color-text-muted);
	}

	.meta-row {
		margin-top: 0.3vh;
	}

	.meta-row b {
		color: var(--color-text);
	}

	.sub-list {
		margin: 0.2vh 0 0 -1vw;
		list-style: none;
		font-size: 0.9vmin;
	}

	.capitalize {
		text-transform: capitalize;
	}

	.footer {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: 0.25vh 0.7vw;
		margin-top: 0.7vh;
		padding-top: 0.7vh;
		border-top: var(--border-subtle);
		color: var(--color-text-muted);
	}

	.stat {
		display: flex;
		align-items: baseline;
		gap: 0.3vw;
	}

	.stat + .stat {
		padding-left: 0.7vw;
		border-left: var(--border-subtle);
	}

	.broken-text {
		color: var(--color-error);
	}

	.quality-good {
		color: var(--color-success);
	}

	.quality-mid {
		color: var(--color-warning);
	}

	.quality-low {
		color: var(--color-error);
	}
</style>
