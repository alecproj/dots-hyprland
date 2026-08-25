local mp = require 'mp'

local PROJECTOR_DELAY = 0.310

local dub_markers = {
    "dub",
    "дуб",
    "дубли"
}

local function is_lampa_stream()
    local path = mp.get_property("path", "")

    return path:match("^https?://127%.0%.0%.1:8090/")
        or path:match("^https?://localhost:8090/")
end

local function russian(lang)
    if not lang then
        return false
    end

    lang = lang:lower()

    return lang == "rus" or lang == "ru"
end

local function is_dub(title)
    if not title then
        return false
    end

    title = title:lower()

    for _, marker in ipairs(dub_markers) do
        if title:find(marker, 1, true) then
            return true
        end
    end

    return false
end

local previous_audio_delay = nil
local configured = false

local function configure_playback()
    if not is_lampa_stream() then
        return
    end

    previous_audio_delay = mp.get_property_number("audio-delay", 0)
    configured = true

    -- Компенсация задержки проектора
    mp.set_property_number("audio-delay", PROJECTOR_DELAY)

    -- DUB -> первая русская дорожка -> остальное оставляем MPC-QT
    local tracks = mp.get_property_native("track-list", {})
    local russian_fallback = nil

    for _, track in ipairs(tracks) do
        if track.type == "audio" and russian(track.lang) then
            russian_fallback = russian_fallback or track.id

            if is_dub(track.title) then
                mp.set_property_number("aid", track.id)
                return
            end
        end
    end

    if russian_fallback then
        mp.set_property_number("aid", russian_fallback)
    end
end

mp.register_event("file-loaded", function()
    mp.add_timeout(0.5, configure_playback)
end)

mp.register_event("end-file", function()
    if configured and previous_audio_delay ~= nil then
        mp.set_property_number("audio-delay", previous_audio_delay)
    end

    previous_audio_delay = nil
    configured = false
end)
