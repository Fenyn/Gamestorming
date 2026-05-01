# Green Bean — Sound Setup Guide

Drop `.ogg` or `.wav` files into `audio/sfx/` matching the filenames below. The SoundManager autoload loads them lazily — missing files are silently skipped, so you can add sounds incrementally.

OGG Vorbis (`.ogg`) is recommended for file size. WAV works but is larger.

## Loops vs One-Shots

**Loops** play continuously until stopped. They should be seamless — set the loop flag in the Godot import settings (select the file in FileSystem, check "Loop" in the Import dock, click Reimport).

**One-shots** play once and stop. No special import settings needed.

---

## Sound Cues

### Grinder
| File | Type | When | Character |
|---|---|---|---|
| `grind_loop.ogg` | Loop | While player cranks the hand grinder | Crunchy, rhythmic grinding. Burr grinder texture |
| `grind_complete.ogg` | One-shot | Grounds are done | Satisfying ding or wooden clunk |

### Aeropress
| File | Type | When | Character |
|---|---|---|---|
| `water_pour_loop.ogg` | Loop | Pouring water into aeropress chamber | Gentle water stream into container |
| `stir_loop.ogg` | Loop | Stirring the slurry | Swishy liquid stirring, muted |
| `steep_tick.ogg` | One-shot | (Reserved — not currently hooked) | Quiet tick for steep countdown |
| `shot_ready.ogg` | One-shot | Shot done steeping, ready to press | Clear alert beep. Must be audible across the shop |
| `over_extract_warn.ogg` | One-shot | Ready window expired, over-extracting | Urgent beep or alarm. Louder/faster than shot_ready |
| `press_loop.ogg` | Loop | While holding click to press plunger | Low mechanical pressure sound, slow hiss |
| `shot_complete.ogg` | One-shot | Press finished, shot extracted | Quick satisfying pop or release |
| `shot_dead.ogg` | One-shot | Shot left too long, died | Flat buzzer or sad tone. Audible across shop |

### Pour Over
| File | Type | When | Character |
|---|---|---|---|
| `pour_loop.ogg` | Loop | Active pour (bloom or main) | Gentle kettle pour, water hitting grounds |
| `drip_loop.ogg` | Loop | Draw-down phase (passive) | Slow dripping into cup. Quieter than pour |
| `drip_done.ogg` | One-shot | Draw-down complete, coffee ready | Gentle chime. Audible from a few steps away |
| `coffee_cooling.ogg` | One-shot | (Reserved — coffee going stale) | Subtle warning tone |

### Steam Wand
| File | Type | When | Character |
|---|---|---|---|
| `steam_hiss_good.ogg` | Loop | Wand in sweet spot (good foam) | Paper-tearing hiss. The "right" steam sound |
| `steam_screech.ogg` | Loop | Wand out of zone (bad position) | High-pitched screech. Immediately tells you it's wrong |
| `steam_texture_loop.ogg` | Loop | Passive texturing phase | Low rumble/hum. Quieter background sound |
| `milk_ready.ogg` | One-shot | Milk reached target temp | Bright ding. Audible across shop — come back and finish! |
| `milk_scald.ogg` | One-shot | Milk overheated and scalded | Harsh alarm/buzz. Punishing |

### Hot Water
| File | Type | When | Character |
|---|---|---|---|
| `kettle_fill_loop.ogg` | Loop | Filling kettle at hot water station | Running water / faucet fill |
| `kettle_full.ogg` | One-shot | Kettle reaches max water | Quick positive beep |

### Syrup
| File | Type | When | Character |
|---|---|---|---|
| `syrup_pump.ogg` | One-shot | Each pump released | Mechanical pump click/thunk. Satisfying |

### Lid
| File | Type | When | Character |
|---|---|---|---|
| `lid_snap.ogg` | One-shot | Lid placed on cup | Plastic snap/click |

### Register
| File | Type | When | Character |
|---|---|---|---|
| `register_beep.ogg` | One-shot | Any POS button pressed | Soft electronic beep |
| `register_charge.ogg` | One-shot | Order charged | Cash register cha-ching |

### Cash Drawer
| File | Type | When | Character |
|---|---|---|---|
| `cash_collect.ogg` | One-shot | Collecting cash from customer | Bill/paper rustle |
| `coin_clink.ogg` | One-shot | Each denomination added to change | Coin clink. Keep it short — it fires rapidly |
| `change_complete.ogg` | One-shot | Correct change given | Register drawer close / satisfied ding |

### Review / Hand-Off
| File | Type | When | Character |
|---|---|---|---|
| `review_good.ogg` | One-shot | 4+ star drink handed off | Happy chime, positive feedback |
| `review_bad.ogg` | One-shot | Below 4 star drink handed off | Flat/muted tone. Not punishing, just "meh" |
| `tip_earned.ogg` | One-shot | 5-star drink, customer leaves tip | Coin drop or cha-ching. Reward feeling |

### Customer
| File | Type | When | Character |
|---|---|---|---|
| `customer_arrive.ogg` | One-shot | Customer reaches the register | Door bell / footstep arrival |
| `customer_impatient.ogg` | One-shot | Patience drops below 25% | Grumble / throat clear. Audible warning |
| `customer_happy.ogg` | One-shot | Customer leaves satisfied | Quick happy hum or "thanks" |
| `customer_angry.ogg` | One-shot | Customer leaves without drink | Frustrated huff. Not over the top |

### Items
| File | Type | When | Character |
|---|---|---|---|
| `item_pickup.ogg` | One-shot | Player picks up any item | Light grab / whoosh |
| `item_place.ogg` | One-shot | Player places item on surface or station | Soft set-down / clunk |

### Day / System
| File | Type | When | Character |
|---|---|---|---|
| `day_start.ogg` | One-shot | Day timer begins | Opening bell or "open for business" jingle |
| `day_end.ogg` | One-shot | Day timer hits zero | Closing bell. Also stops all active loops |
| `timer_warning.ogg` | One-shot | 30 seconds remaining | Urgent but not alarming. Clock tick or bell |

---

## Priority Order

If you're adding sounds incrementally, this order gives the most gameplay impact:

1. **Cross-shop alerts** — `shot_ready`, `over_extract_warn`, `milk_ready`, `milk_scald`, `drip_done` (these enable multitasking)
2. **Steam feedback** — `steam_hiss_good`, `steam_screech` (core to the steaming mini-game feel)
3. **Day bookends** — `day_start`, `day_end`, `timer_warning`
4. **Tactile feedback** — `item_pickup`, `item_place`, `lid_snap`, `syrup_pump`, `register_beep`
5. **Customer life** — `customer_arrive`, `customer_impatient`, `customer_happy`
6. **Activity loops** — `grind_loop`, `pour_loop`, `press_loop`, `drip_loop`
7. **Everything else** — fill in as you go

## Tips

- Keep one-shots short (0.2-1.0s). Loops can be any length but should tile seamlessly.
- Cross-shop alerts should be louder and more distinct than local feedback sounds.
- The steam hiss/screech swap is the most important audio feedback in the game — getting it right makes steaming feel real.
- `coin_clink` fires on every denomination tap, so keep it very short (~0.1s) to avoid overlap stacking.
