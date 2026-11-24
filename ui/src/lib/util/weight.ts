// Stack weight for slot corners: grams under 1kg ("100g"), otherwise trimmed kg ("3kg", "4.5kg")
export function formatWeight(kg: number): string {
	if (!kg || kg <= 0) return '';
	if (kg < 1) return `${Math.round(kg * 1000)}g`;
	return `${trimKg(kg)}kg`;
}

// One decimal, no trailing ".0" ("3.8", "5")
export function trimKg(kg: number): string {
	return String(Number(kg.toFixed(1)));
}
