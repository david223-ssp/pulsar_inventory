// Item icons live at ui/images/items/*.webp (sibling to ui/dist/, never bundled), keep the path a runtime string, not an import

import type { InventorySlotItem, ItemDefinition } from '../types';
import { parseMetaData } from './metadata';

export function getItemImage(instance: InventorySlotItem | undefined | null, itemData: ItemDefinition | undefined | null): string {
	const metadata = parseMetaData(instance?.MetaData);
	if (metadata.CustomItemImage) return metadata.CustomItemImage;

	const staticMeta = parseMetaData(itemData?.staticMetadata as never);
	if (staticMeta.CustomItemImage) return staticMeta.CustomItemImage;

	if (itemData?.iconOverride) return `../images/items/${itemData.iconOverride}.webp`;
	return `../images/items/${itemData?.name ?? 'ph'}.webp`;
}

export function getItemLabel(instance: InventorySlotItem | undefined | null, itemData: ItemDefinition | undefined | null): string {
	const metadata = parseMetaData(instance?.MetaData);
	if (metadata.CustomItemLabel) return metadata.CustomItemLabel;
	return itemData?.label ?? 'Unknown';
}
