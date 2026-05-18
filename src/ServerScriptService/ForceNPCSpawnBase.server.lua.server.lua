--!nonstrict
-- ForceNPCSpawnBase.server.lua
-- Disabled.
--
-- The old version moved every wild NPC back to the spawn base after it spawned,
-- which fought the zone spawner and made zone-specific NPC placement look broken.
-- ZoneNPCSpawner.server.lua now owns wild NPC placement and scattering.

print("[ForceNPCSpawnBase] Disabled. ZoneNPCSpawner owns wild NPC placement.")
