Config = Config or {}
_itemsSource = _itemsSource or {}

-- prop model used for the physical world object spawned near a ground drop
Config.DropProp = "prop_med_bag_01b"
Config.DropPropDistance = 25.0

-- item name to sync with wallet cash (see items/misc.lua's "cash" entry), or false to disable
Config.CashAsItem = 'cash'

-- Itens físicos no chão (client/drops.lua, server/ground_items.lua): cada item de uma dropzone é um prop seu, no
-- sítio onde caiu, que se apanha com o target. Enabled = false volta ao saco único por dropzone (Config.DropProp).
Config.GroundItems = {
	Enabled = true,
	PickupRange = 2.5,   -- metros entre o jogador e o item para o apanhar
	ScatterRadius = 1.2, -- itens arrastados para o painel do chão espalham-se até esta distância do centro
	MaxDrift = 4.0,      -- uma posição guardada mais longe do centro do que isto é refeita
	DropAhead = 0.55,    -- "largar" põe o item esta distância à frente do jogador
	-- prop de cada item; um modelo que não exista cai em DefaultProp, e esse em Config.DropProp
	DefaultProp = "prop_paper_bag_small",
	Props = {
		cash = "prop_cash_pile_01",
		phone = "prop_npc_phone_02",
		water = "prop_ld_flow_bottle",
		coffee = "p_ing_coffeecup_01",
		sandwich = "prop_sandwich_01",
		sandwich_blt = "prop_sandwich_01",
		armor = "prop_armour_pickup",
		heavyarmor = "prop_armour_pickup",
		pdarmor = "prop_armour_pickup",
		radio = "prop_cs_walkie_talkie",
		radio_shitty = "prop_cs_walkie_talkie",
	},
	-- por tipo de item (items/*.lua: 1 básico, 2 arma, 9 munição, 10 contentor...). As armas (tipo 2) usam o modelo da própria arma.
	TypeProps = {
		[9] = "prop_ld_ammo_pack_01",
		[10] = "prop_cs_heist_bag_01",
	},
	-- Apanhar: etiqueta flutuante por cima do item mais perto/para onde olhas, e [E] apanha (como no WHIP).
	Prompt = true,
	PromptRange = 2.0,  -- metros entre o jogador e o item para a etiqueta aparecer
	PromptKey = 38,     -- tecla do "apanhar" (38 = E)
	PromptKeyLabel = "E",
	Outline = true,     -- contorno no item que a etiqueta está a mostrar
	-- Target (olhar e escolher "Apanhar" / "Abrir monte"). Com a etiqueta ligada fica desligado por defeito.
	UseTarget = false,
	Text = {
		Pickup = "Apanhar %s",
		Open = "Abrir monte",
	},
}

-- Colocar (client/place.lua): "Place" no menu do item mostra uma cópia transparente que segue a câmara.
-- [E] coloca o item exatamente ali, [Roda do rato] roda-o, [C] cancela.
Config.PlaceMode = {
	MaxDistance = 3.5,  -- metros entre o jogador e o sítio onde o item fica
	Alpha = 160,        -- transparência da pré-visualização (0-255)
	RotateStep = 10.0,  -- graus por cada passo da roda do rato
	Timeout = 60000,    -- ms até o modo colocar acabar sozinho
	Anim = { dict = "pickup_object", clip = "putdown_low" },
	Blacklist = {},     -- [nome] = true: não se pode colocar
}

-- Dar em mão e atirar (client/give.lua), como no WHIP: "Give" no menu do item põe-no na mão; [E] dá à pessoa para
-- onde estás virado, [Clique esquerdo] atira-o para onde apontas, [C] cancela.
Config.GiveMode = {
	MaxDistance = 3.0,       -- metros até à pessoa a quem dás
	AimAngle = 30.0,         -- graus: a pessoa tem de estar mais ou menos à tua frente (para onde a câmara aponta)
	Timeout = 30000,         -- ms até o modo dar acabar sozinho
	ThrowSpeed = 14.0,       -- m/s com que o item sai da mão
	ThrowMaxDistance = 35.0, -- metros: um item que caia mais longe do que isto é recusado (fica contigo)
	ThrowReleaseMs = 350,    -- ms da animação de atirar até o item sair da mão
	VisualRange = 80.0,      -- metros: quem está mais longe não vê o item a voar
	ThrowAnim = { dict = "anim@narcotics@trash", clip = "drop_front" },
	GiveAnim = { dict = "mp_common", giver = "givetake1_a", receiver = "givetake1_b" },
	-- onde o item fica na mão direita (osso 57005): posição e rotação; ItemOffsets por item para acertar
	HandOffset = { x = 0.12, y = 0.02, z = -0.02, rx = -90.0, ry = 0.0, rz = 0.0 },
	ItemOffsets = {},
	Blacklist = {},      -- [nome] = true: não se pode dar
	ThrowBlacklist = {}, -- [nome] = true: não se pode atirar
	Text = {
		HintTarget = "[E] Dar a esta pessoa  |  [Clique esquerdo] Atirar  |  [C] Cancelar",
		HintNoTarget = "Vira-te para alguém para dar  |  [Clique esquerdo] Atirar  |  [C] Cancelar",
		HintPlace = "[E] Colocar %s  |  [Roda do rato] Rodar  |  [C] Cancelar",
		HintPlaceInvalid = "Aponta para o chão, mais perto  |  [C] Cancelar",
		Cancelled = "Cancelaste",
		InVehicle = "Não podes fazer isso dentro de um veículo",
		TimedOut = "Demoraste demasiado",
		YouGave = "Deste %sx %s",
		YouThrew = "Atiraste %sx %s",
		YouPlaced = "Colocaste %sx %s",
		YouPickedUp = "Apanhaste %sx %s",
		YouReceived = "Recebeste %sx %s",
		NoTarget = "Não há ninguém para receber",
		TooFar = "Estás demasiado longe",
		TooFast = "Calma",
		ItemGone = "Já não tens esse item",
		NoRoom = "Não tens espaço no inventário",
		TheyHaveNoRoom = "A pessoa não tem espaço no inventário",
		TheyHadNoRoomYou = "Alguém tentou dar-te um item mas não tens espaço",
		TheyAreTooHeavy = "A pessoa não aguenta com tanto peso",
		CantGive = "Esse item não se pode dar",
		CantThrow = "Esse item não se pode atirar",
		CantPlace = "Esse item não se pode colocar",
		PlaceFailed = "Não foi possível colocar o item",
		GroundFull = "Não cabe mais nada neste sítio",
		GiveFailed = "Não foi possível dar o item",
		ThrowFailed = "Não foi possível atirar o item",
		PickupFailed = "Não foi possível apanhar o item",
		AlreadyTaken = "Alguém já apanhou isso",
	},
}

-- Character equipment shown around the silhouette in the UI, stored as its own inventory per character (owner = SID).
-- Slot numbers match the UI: 1 backpack, 2 armor, 3 phone, 4 parachute, 5 wallet, 6 key.
-- Only slots listed in `slots` accept items; the others are display-only for now (other resources still look for
-- armor/phone/etc. in the player inventory, so moving those out would break them).
-- Health & Injuries tab (client/health.lua, server/health.lua). pulsar_damage owns the data and all healing;
-- the inventory only shows it and, on "Heal Injury", uses the first of these items the player carries through the
-- normal item-use flow (so pulsar_damage's own item effect, animation and removal apply).
Config.HealthTab = {
	resource = "pulsar_damage",
	healItems = { "bandage", "firstaid", "ifak", "gauze", "tourniquet" },
	criticalThreshold = 70, -- damage at/above this is Critical; Major starts at pulsar_damage's limpThreshold
}

Config.Equipment = {
	invType = 300,
	backpackSlot = 1,
	slots = {
		-- any item flagged `backpack = true` (a type 10 container); its storage opens under the player pane while equipped
		[1] = { id = "backpack", accepts = function(item) return item ~= nil and item.backpack == true and item.container ~= nil end },
	},
}

function hasValue(tbl, value)
	for k, v in ipairs(tbl or {}) do
		if v == value or (type(v) == "table" and hasValue(v, value)) then
			return true
		end
	end
	return false
end

Config.StartItems = {
	{ name = "govid", count = 1 },
	{ name = "phone", count = 1 },
	{ name = "water", count = 5 },
	{ name = "sandwich_blt", count = 5 },
	{ name = "bandage", count = 5 },
	{ name = "coffee", count = 2 },
}

Config.ShopItemSets = {
	------------------------------------
	-- General Stores like 24/7 etc.. --
	------------------------------------
	[1] = {
		"sandwich",
		"sandwich_egg",
		"water",
		"bandage",
		"cigarette_pack",
		"coffee",
		"soda",
		"energy_pepe",
		"chocolate_bar",
		-- "donut",
		"crisp",
		"rolling_paper",
		{ item = "moonshine_jar", count = 50, price = 2 },
	},
	--------------
	-- Hardware --
	--------------
	[2] = {
		"screwdriver",
		"WEAPON_HAMMER",
		"WEAPON_CROWBAR",
		"WEAPON_GOLFCLUB",
		"repairkit",
		"fertilizer_nitrogen",
		"fertilizer_phosphorus",
		"fertilizer_potassium",
		"gascan",
		"redlight",
		-- "camping_chair",
		-- "beanbag",
		"plastic_wrap",
		"baggy",
		"binoculars",
		"WEAPON_SHOVEL",
		"cloth",
		"pipe",
		"nails",
		"drill",
	},
	--------------------------
	-- Burger Shot Supplies --
	--------------------------
	[3] = {
		"cup",
		"bun",
		"patty",
		"pickle"
	},
	----------------
	-- Ammunation --
	----------------
	[4] = {
		"armor",
		"heavyarmor",
		"WEAPON_PISTOL",
		"WEAPON_COMBATPISTOL",
		"AMMO_PISTOL",
		"WEAPON_BAT"
	},
	-----------------------
	-- Electronics Store --
	-----------------------
	[5] = { 
		"phone",
		"radio_shitty",
		"camera",
		"electronics_kit",
		"laptop",
		"gps",
		"case_black",
		"case_blue",
		"case_pink",
		"case_white",
		"case_gold",
	},
	-------------------
	-- Police Armory --
	-------------------
	[6] = {
		"radio",
		"binoculars",
		"camera",
		"phone",
		"pd_watch",
		"pdarmor",
		"ifak",
		"pdhandcuffs",
		"spikes",
		"WEAPON_FLASHLIGHT",
		"WEAPON_GLOCK17_PD",
		"AMMO_PISTOL_PD",
		"AMMO_SMG_PD",
		"WEAPON_M4_PD",
		"AMMO_RIFLE_PD",
		"AMMO_STUNGUN",

		"scuba_gear",

		-- SWAT
		"det_cord",
		"WEAPON_FLASHBANG",
		"WEAPON_SMOKEGRENADE",
		"adrenaline",
		"AMMO_SHOTGUN_PD",
		"WEAPON_BULLPUPSHOTGUN_PD",
	},
	--------------------
	-- Medical Armory --
	--------------------
	[7] = { 
		"traumakit",
		"medicalkit",
		"firstaid",
		"bandage",
		"morphine",
		"radio",
		"phone",
		"scuba_gear",
	},
	-------------------
	-- Hunting Store --
	-------------------
	[8] = {
		"AMMO_SNIPER",
		"WEAPON_KNIFE",
		"hunting_bait",
		"hunting_map_light",
		"hunting_map_dark",
		-- "deer_bait",
		-- "boar_bait",
		-- "pig_bait",
		-- "chicken_bait",
		-- "rabbit_bait",
		-- "exotic_bait",
	},
	----------------
	-- DOC Armory --
	----------------
	[9] = {
		"pdarmor",
		"traumakit",
		"ifak",
		"pdhandcuffs",
		"WEAPON_FLASHLIGHT",
		"WEAPON_BEANBAG",
		"AMMO_PISTOL_PD",
		"AMMO_BEANBAG_PD",
		"AMMO_SMG_PD",
		-- "AMMO_RIFLE_PD",
		"AMMO_STUNGUN",
		"radio",
		"binoculars",
		"megaphone",
		"camera",
		"phone",
		"WEAPON_FLASHBANG",
		"WEAPON_SMOKEGRENADE",
	},
	-------------------
	-- Water Machine --
	-------------------
	[10] = { "water" },
	--------------------
	-- Coffee Machine --
	--------------------
	[11] = { "coffee" },
	-----------------------------
	-- Drinks Vending Machines --
	-----------------------------
	[12] = {
		"water",
		"soda",
		"energy_pepe",
	},
	---------------------------
	-- Food Vending Machines --
	---------------------------
	[13] = { 
		"chocolate_bar",
		-- "donut",
		"crisp",
	},
	----------
	---
	----------
	[14] = {
		"firstaid",
		"bandage",
	},
	---------------
	--- Gas Pump --
	---------------
	[15] = {
		"WEAPON_PETROLCAN",
	},
	-----------------
	--- Wholesaler --
	-----------------
	[16] = {
		{ item = "dough", count = 1000, price = 3 },
		{ item = "eggs", count = 1000, price = 3 },
		{ item = "loaf", count = 1000, price = 3 },
		{ item = "sugar", count = 1000, price = 3 },
		{ item = "flour", count = 1000, price = 3 },
		{ item = "rice", count = 1000, price = 3 },
		{ item = "icing", count = 1000, price = 3 },
		{ item = "tea_leaf", count = 1000, price = 3 },
		{ item = "plastic_cup", count = 1000, price = 3 },
		{ item = "coffee_beans", count = 1000, price = 3 },
		{ item = "burgershot_cup", count = 1000, price = 3 },
		{ item = "bun", count = 1000, price = 3 },
		{ item = "cheese", count = 1000, price = 3 },
		{ item = "pineapple", count = 1000, price = 3 },
		{ item = "raspberry", count = 1000, price = 3 },
		{ item = "peach_juice", count = 1000, price = 3 },
		{ item = "coconut_milk", count = 1000, price = 3 },
		{ item = "yeast", count = 1000, price = 3 },
		{ item = "grain", count = 1000, price = 3 },
		{ item = "hobs", count = 1000, price = 3 },
		{ item = "ginger", count = 1000, price = 3 },
		{ item = "hotdog_single", count = 1000, price = 3 },
		{ item = "popcorn_kernal", count = 1000, price = 3 },
		{ item = "popcorn_bucket", count = 1000, price = 3 },
		{ item = "water" },
		{ item = "milk_can", count = 1000, price = 3 },
		{ item = "rusty_empty", count = 1000, price = 3, job = "rustybrowns" },

		{ item = "jaeger", count = 10, price = 3 },
		{ item = "raspberry_liqueur", count = 30, price = 3 },
		{ item = "sparkling_wine", count = 30, price = 3 },
		{ item = "rum", count = 50, price = 3 },
		{ item = "whiskey", count = 50, price = 3 },
		{ item = "vodka", count = 50, price = 3 },
		{ item = "tequila", count = 50, price = 3 },

		-- { item = "taco_chicken", count = 1000, price = 2 },
		-- { item = "taco_steak", count = 1000, price = 2 },
		-- { item = "taco_tortilla", count = 1000, price = 2 },
		-- { item = "taco_beef", count = 1000, price = 2 },
		-- { item = "taco_cheese", count = 1000, price = 2 },
		-- { item = "torta_roll", count = 1000, price = 2 },

		{ item = "keg", count = 1, price = 3 },

		{ item = "bento_box", job = "uwu" },
		{ item = "burgershot_bag", job = "burgershot" },

		{ item = "foodbag" },
		{ item = "cardboard_box" },
		{ item = "paper_bag" },
		{ item = "coffee_holder" },
		-- BELOW WILL NEED
		-- REMOVED AFTER
		-- SERVER POPULATES
		-- "peas",
		-- "orange",
		-- "tomato",
		-- "lettuce",
		-- "beef",
		-- "chicken",
		-- "cucumber",
		-- "potato",
		-- "unk_meat",
		-- "vension",
	},
	[17] = {
		"weed_joint",
		"rolling_paper",
	},
	-------------------
	-- Liquor Stores --
	-------------------
	[18] = { 
		"vodka",
		"beer",
		"water",
		"bandage",
		"cigarette_pack",
		"coffee",
		"soda",
		"energy_pepe",
		"chocolate_bar",
		-- "donut",
		"crisp",
		"rolling_paper",
	},
	[19] = {
		"wine_bottle",
	},
	[20] = {
		"fishing_rod",
		"fishing_bait_worm",
		"fishing_bait_lugworm",
		"WEAPON_KNIFE",
	},
	-------------------
	-- Fishing Store --
	-------------------
	[21] = {
		"fishing_rod",
		"fishing_net",
		"fishing_bait_worm",
		"fishing_bait_lugworm",
		"WEAPON_KNIFE",
	},
	[22] = {
		--"personal_plates",
	},
	[23] = {
		"hotdog",

		"water",
	},
	[24] = {
		"cheeseburger",
		"water",
	},
	[25] = {
		"taco_chicken",
		"taco_steak",
		"taco_tortilla",
		"taco_beef",
		"taco_cheese",
		"torta_roll",
		"taco_plastic_cups",
	},
}
