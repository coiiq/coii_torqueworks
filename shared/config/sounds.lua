-- Runtime audio triggers. Individual engine and turbo sound assignments live
-- beside their parts in parts.lua; streamed sound packs stay in fxmanifest.lua.
Config.TurboAudio = {
    minimumRpm = 6000,
    referenceRedlineRpm = 8000,
    minimumThrottleBeforeRelease = 0.55,
    maximumThrottleAfterRelease = 0.25,
    cooldownMs = 500,
    syncDistance = 45.0
}
