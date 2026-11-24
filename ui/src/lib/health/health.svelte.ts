// Health & Injuries tab state. pulsar_damage owns the data and all healing; the inventory's client/health.lua relays it:
//   getHealthData (UI -> Lua, returns the payload) | setHealthData (Lua -> UI, live) | healInjury (UI -> Lua, { id })
// Injuries arrive either as a list or as a map keyed by body part ({ RLEG = { damage, bleeding } } or { ['right-leg'] = ... });
// both are normalized here, the Lua side never changes shape.

import { Nui } from '../nui';

export type BodyPart =
	| 'HEAD'
	| 'NECK'
	| 'SPINE'
	| 'UPPER_BODY'
	| 'LOWER_BODY'
	| 'LARM'
	| 'LHAND'
	| 'LFINGER'
	| 'LLEG'
	| 'LFOOT'
	| 'RARM'
	| 'RHAND'
	| 'RFINGER'
	| 'RLEG'
	| 'RFOOT';

export type Severity = 'minor' | 'major' | 'critical';

export interface Injury {
	/** Sent back verbatim on healInjury: the list item's id, or the map key it arrived under */
	id: string;
	part: BodyPart | null;
	/** Raw part name as received, shown when it doesn't map to a known part */
	rawPart: string;
	damage: number;
	bleeding: boolean;
	severity: Severity;
}

export interface Thresholds {
	major: number;
	critical: number;
}

const DEFAULT_THRESHOLDS: Thresholds = { major: 40, critical: 70 };

export const healthState = $state({
	/** null until the first answer; false when pulsar_damage isn't running or sent nothing usable */
	available: null as boolean | null,
	health: 0,
	armor: 0,
	stamina: 0,
	injuries: [] as Injury[],
	thresholds: DEFAULT_THRESHOLDS as Thresholds,
	/** Medical items in the order Lua will try them on "Heal Injury" (display only) */
	healItems: [] as string[],
});

// every spelling we've seen for a part: RLEG, rleg, right-leg, right_leg, "Right Leg", rightleg...
const PART_ALIASES: Record<string, BodyPart> = {
	head: 'HEAD',
	neck: 'NECK',
	spine: 'SPINE',
	back: 'SPINE',
	upperbody: 'UPPER_BODY',
	torso: 'UPPER_BODY',
	chest: 'UPPER_BODY',
	body: 'UPPER_BODY',
	lowerbody: 'LOWER_BODY',
	pelvis: 'LOWER_BODY',
	larm: 'LARM',
	leftarm: 'LARM',
	lhand: 'LHAND',
	lefthand: 'LHAND',
	lfinger: 'LFINGER',
	lefthandfinger: 'LFINGER',
	leftfinger: 'LFINGER',
	lleg: 'LLEG',
	leftleg: 'LLEG',
	lfoot: 'LFOOT',
	leftfoot: 'LFOOT',
	rarm: 'RARM',
	rightarm: 'RARM',
	rhand: 'RHAND',
	righthand: 'RHAND',
	rfinger: 'RFINGER',
	righthandfinger: 'RFINGER',
	rightfinger: 'RFINGER',
	rleg: 'RLEG',
	rightleg: 'RLEG',
	rfoot: 'RFOOT',
	rightfoot: 'RFOOT',
};

export function normalizePart(raw: unknown): BodyPart | null {
	if (typeof raw !== 'string') return null;
	return PART_ALIASES[raw.toLowerCase().replace(/[^a-z]/g, '')] ?? null;
}

export const PART_LABELS: Record<BodyPart, string> = {
	HEAD: 'Head',
	NECK: 'Neck',
	SPINE: 'Spine',
	UPPER_BODY: 'Upper Body',
	LOWER_BODY: 'Lower Body',
	LARM: 'Left Arm',
	LHAND: 'Left Hand',
	LFINGER: 'Left Hand Finger',
	LLEG: 'Left Leg',
	LFOOT: 'Left Foot',
	RARM: 'Right Arm',
	RHAND: 'Right Hand',
	RFINGER: 'Right Hand Finger',
	RLEG: 'Right Leg',
	RFOOT: 'Right Foot',
};

export const SEVERITY_LABELS: Record<Severity, string> = { minor: 'Minor', major: 'Major', critical: 'Critical' };

type Region = 'head' | 'neck' | 'torso' | 'arm' | 'hand' | 'leg' | 'foot';
const PART_REGION: Record<BodyPart, Region> = {
	HEAD: 'head',
	NECK: 'neck',
	SPINE: 'torso',
	UPPER_BODY: 'torso',
	LOWER_BODY: 'torso',
	LARM: 'arm',
	RARM: 'arm',
	LHAND: 'hand',
	RHAND: 'hand',
	LFINGER: 'hand',
	RFINGER: 'hand',
	LLEG: 'leg',
	RLEG: 'leg',
	LFOOT: 'foot',
	RFOOT: 'foot',
};

// headline per body region and severity ("Fractured Arm", "Bruised Leg", "Concussion")
const DIAGNOSIS: Record<Region, Record<Severity, string>> = {
	head: { minor: 'Concussion', major: 'Head Trauma', critical: 'Skull Fracture' },
	neck: { minor: 'Neck Strain', major: 'Whiplash', critical: 'Neck Trauma' },
	torso: { minor: 'Bruised Ribs', major: 'Cracked Ribs', critical: 'Internal Bleeding' },
	arm: { minor: 'Sprained Arm', major: 'Bruised Arm', critical: 'Fractured Arm' },
	hand: { minor: 'Sprained Hand', major: 'Bruised Hand', critical: 'Fractured Hand' },
	leg: { minor: 'Sprained Leg', major: 'Bruised Leg', critical: 'Fractured Leg' },
	foot: { minor: 'Sprained Ankle', major: 'Bruised Foot', critical: 'Fractured Foot' },
};

export function diagnosis(injury: Injury): string {
	if (!injury.part) return `${SEVERITY_LABELS[injury.severity]} Injury`;
	return DIAGNOSIS[PART_REGION[injury.part]][injury.severity];
}

export function partLabel(injury: Injury): string {
	return injury.part ? PART_LABELS[injury.part] : injury.rawPart.replace(/[-_]+/g, ' ');
}

function clampPct(v: unknown): number {
	const n = Number(v);
	return Number.isFinite(n) ? Math.max(0, Math.min(100, Math.round(n))) : 0;
}

export function severityFor(damage: number, t: Thresholds): Severity {
	if (damage >= t.critical) return 'critical';
	if (damage >= t.major) return 'major';
	return 'minor';
}

function toInjury(id: string, raw: Record<string, unknown>, partName: unknown, t: Thresholds): Injury | null {
	const damage = clampPct(raw.damage);
	const bleeding = !!raw.bleeding && Number(raw.bleeding) !== 0;
	// pulsar_damage prunes healed limbs, but don't show an empty entry if one slips through
	if (damage <= 0 && !bleeding) return null;
	const rawPart = typeof partName === 'string' ? partName : id;
	return { id, part: normalizePart(rawPart), rawPart, damage, bleeding, severity: severityFor(damage, t) };
}

export function normalizeInjuries(input: unknown, t: Thresholds): Injury[] {
	const out: Injury[] = [];
	if (Array.isArray(input)) {
		input.forEach((raw, i) => {
			if (!raw || typeof raw !== 'object') return;
			const r = raw as Record<string, unknown>;
			const part = r.part ?? r.bone ?? r.limb ?? r.name;
			const id = r.id != null ? String(r.id) : typeof part === 'string' ? part : String(i + 1);
			const inj = toInjury(id, r, part, t);
			if (inj) out.push(inj);
		});
	} else if (input && typeof input === 'object') {
		for (const [key, raw] of Object.entries(input as Record<string, unknown>)) {
			if (!raw || typeof raw !== 'object') continue;
			const r = raw as Record<string, unknown>;
			const inj = toInjury(r.id != null ? String(r.id) : key, r, r.part ?? key, t);
			if (inj) out.push(inj);
		}
	}
	// worst first, then bleeding
	const rank: Record<Severity, number> = { critical: 0, major: 1, minor: 2 };
	return out.sort((a, b) => rank[a.severity] - rank[b.severity] || Number(b.bleeding) - Number(a.bleeding) || b.damage - a.damage);
}

export function applyHealthData(data: unknown): void {
	if (!data || typeof data !== 'object') {
		healthState.available = false;
		return;
	}
	const d = data as Record<string, unknown>;
	const hasValues = d.health != null || d.armor != null || d.stamina != null || d.injuries != null;
	if (d.available === false || !hasValues) {
		healthState.available = false;
		healthState.injuries = [];
		return;
	}

	const t = (d.thresholds ?? {}) as Partial<Thresholds>;
	const thresholds: Thresholds = {
		major: Number(t.major) || DEFAULT_THRESHOLDS.major,
		critical: Number(t.critical) || DEFAULT_THRESHOLDS.critical,
	};

	healthState.available = true;
	healthState.health = clampPct(d.health);
	healthState.armor = clampPct(d.armor);
	healthState.stamina = clampPct(d.stamina);
	healthState.thresholds = thresholds;
	healthState.injuries = normalizeInjuries(d.injuries, thresholds);
	if (Array.isArray(d.healItems)) healthState.healItems = d.healItems.filter((n): n is string => typeof n === 'string');
}

export async function requestHealthData(): Promise<void> {
	const data = await Nui.getHealthData();
	// undefined = dev build / no answer: keep whatever setHealthData already delivered
	if (data !== undefined) applyHealthData(data);
}

export function healInjury(injury: Injury): void {
	void Nui.healInjury(injury.id);
}
