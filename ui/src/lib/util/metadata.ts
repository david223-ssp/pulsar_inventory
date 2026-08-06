// MetaData sometimes arrives from Lua as a table-literal string instead of a real JSON object

import type { ItemMetaData } from '../types';

function lua2json(lua: string): ItemMetaData {
	const jsonish = lua.replace(/\[([^[\]]+)\]\s*=/g, (_match, key) => `${key} :`).replace(/,(\s*)\}/gm, (_match, tail) => `${tail}}`);
	return JSON.parse(jsonish) as ItemMetaData;
}

/** Accepts a real object, a Lua-table-literal string, undefined, or null, always returns a plain object */
export function parseMetaData(raw: ItemMetaData | string | undefined | null): ItemMetaData {
	if (!raw) return {};
	if (typeof raw === 'object') return raw;
	try {
		return lua2json(raw);
	} catch {
		return {};
	}
}
