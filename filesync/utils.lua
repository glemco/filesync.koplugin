--- Shared utility functions for the FileSync plugin.
--- Provides common helpers used across multiple modules:
---   - getPluginDir(): returns the absolute path to the plugin root directory
---   - shellEscape(s): escapes a string for safe use in shell commands

local Utils = {}

-- Cached plugin directory path (computed once on first call)
local _cached_plugin_dir = nil

--- Get the plugin root directory path.
--- Computes the path from the source location of this file and caches the result.
--- @return string: absolute path to the plugin directory (e.g., "/mnt/us/koreader/plugins/filesync.koplugin")
function Utils.getPluginDir()
    if _cached_plugin_dir then return _cached_plugin_dir end
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@(.+)")
    if script_path then
        -- This file is filesync/utils.lua, go up one level to get the plugin root
        local filesync_dir = script_path:match("(.+)/[^/]+$") or "."
        _cached_plugin_dir = filesync_dir:match("(.+)/[^/]+$") or "."
    else
        _cached_plugin_dir = "."
    end
    return _cached_plugin_dir
end

--- Escape a string for safe use in a shell command (wrap in single quotes).
--- @param s string|nil: the string to escape
--- @return string: the shell-safe escaped string
function Utils.shellEscape(s)
    if not s then return "''" end
    -- Replace each single quote with: end quote, escaped quote, start quote
    local escaped = s:gsub("'", "'\\''")
    return "'" .. escaped .. "'"
end

return Utils
