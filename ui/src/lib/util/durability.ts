// linear decay from CreateDate over `durability` seconds, recomputed on every render
export function calcDurability(createDate: number | undefined, durabilitySeconds: number | undefined): number | null {
	if (!createDate || !durabilitySeconds) return null;
	return Math.ceil(100 - ((Math.floor(Date.now() / 1000) - createDate) / durabilitySeconds) * 100);
}
