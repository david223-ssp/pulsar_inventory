<!-- Renders a FontAwesome solid icon by name; unrecognized names fall back to circle-exclamation -->
<script lang="ts">
	import {
		faBan,
		faCheck,
		faCircleCheck,
		faCircleExclamation,
		faDollarSign,
		faHammer,
		faMagnifyingGlass,
		faMinus,
		faPlus,
		faQuestion,
		faTriangleExclamation,
		faVolumeHigh,
		faVolumeXmark,
		faWeightHanging,
		faXmark,
		type IconDefinition,
	} from '@fortawesome/free-solid-svg-icons';

	const ICONS: Record<string, IconDefinition> = {
		xmark: faXmark,
		'magnifying-glass': faMagnifyingGlass,
		plus: faPlus,
		minus: faMinus,
		'circle-check': faCircleCheck,
		check: faCheck,
		'circle-exclamation': faCircleExclamation,
		question: faQuestion,
		'volume-high': faVolumeHigh,
		'volume-xmark': faVolumeXmark,
		'weight-hanging': faWeightHanging,
		ban: faBan,
		hammer: faHammer,
		'triangle-exclamation': faTriangleExclamation,
		'dollar-sign': faDollarSign,
		dollar: faDollarSign,
	};

	let { name, size = '1em' }: { name: string; size?: string } = $props();

	const icon = $derived(ICONS[name] ?? faCircleExclamation);
	const path = $derived(icon.icon[4] as string);
	const viewBox = $derived(`0 0 ${icon.icon[0]} ${icon.icon[1]}`);
</script>

<svg {viewBox} width={size} height={size} fill="currentColor" aria-hidden="true">
	<path d={path} />
</svg>
