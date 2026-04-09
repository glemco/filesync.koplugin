-- Stub KOReader dependencies that updater.lua requires at load time
package.loaded["gettext"] = function(s) return s end
package.loaded["ffi/util"] = { template = function(s, ...) return s end }

-- Stub filesync/utils to avoid path-detection side effects
package.loaded["filesync/utils"] = {
    getPluginDir = function() return "/tmp/fake_plugin" end,
    shellEscape = function(s)
        if not s then return "''" end
        return "'" .. s:gsub("'", "'\\''") .. "'"
    end,
}

local Updater = require("filesync/updater")

describe("filesync.updater", function()

    describe("_parseVersion", function()

        it("parses a standard semver string", function()
            local v = Updater:_parseVersion("1.2.3")
            assert.are.equal(1, v.major)
            assert.are.equal(2, v.minor)
            assert.are.equal(3, v.patch)
        end)

        it("strips leading v prefix", function()
            local v = Updater:_parseVersion("v2.0.1")
            assert.are.equal(2, v.major)
            assert.are.equal(0, v.minor)
            assert.are.equal(1, v.patch)
        end)

        it("parses version 0.0.0", function()
            local v = Updater:_parseVersion("0.0.0")
            assert.are.equal(0, v.major)
            assert.are.equal(0, v.minor)
            assert.are.equal(0, v.patch)
        end)

        it("parses large version numbers", function()
            local v = Updater:_parseVersion("100.200.300")
            assert.are.equal(100, v.major)
            assert.are.equal(200, v.minor)
            assert.are.equal(300, v.patch)
        end)

        it("returns nil for nil input", function()
            assert.is_nil(Updater:_parseVersion(nil))
        end)

        it("returns nil for empty string", function()
            assert.is_nil(Updater:_parseVersion(""))
        end)

        it("returns nil for non-semver string", function()
            assert.is_nil(Updater:_parseVersion("not-a-version"))
        end)

        it("returns nil for partial version", function()
            assert.is_nil(Updater:_parseVersion("1.2"))
        end)

        it("returns nil for version with extra non-numeric parts", function()
            -- "1.2.3-beta" would actually match because the pattern grabs "1.2.3"
            -- But "1.2.x" should fail
            assert.is_nil(Updater:_parseVersion("1.2.x"))
        end)
    end)

    describe("_isNewer", function()

        it("returns true when remote major is higher", function()
            local remote = {major = 2, minor = 0, patch = 0}
            local local_ = {major = 1, minor = 9, patch = 9}
            assert.is_true(Updater:_isNewer(remote, local_))
        end)

        it("returns true when remote minor is higher", function()
            local remote = {major = 1, minor = 3, patch = 0}
            local local_ = {major = 1, minor = 2, patch = 9}
            assert.is_true(Updater:_isNewer(remote, local_))
        end)

        it("returns true when remote patch is higher", function()
            local remote = {major = 1, minor = 2, patch = 4}
            local local_ = {major = 1, minor = 2, patch = 3}
            assert.is_true(Updater:_isNewer(remote, local_))
        end)

        it("returns false when versions are equal", function()
            local remote = {major = 1, minor = 2, patch = 3}
            local local_ = {major = 1, minor = 2, patch = 3}
            assert.is_false(Updater:_isNewer(remote, local_))
        end)

        it("returns false when local major is higher", function()
            local remote = {major = 1, minor = 0, patch = 0}
            local local_ = {major = 2, minor = 0, patch = 0}
            assert.is_false(Updater:_isNewer(remote, local_))
        end)

        it("returns false when local minor is higher", function()
            local remote = {major = 1, minor = 2, patch = 0}
            local local_ = {major = 1, minor = 3, patch = 0}
            assert.is_false(Updater:_isNewer(remote, local_))
        end)

        it("returns false when local patch is higher", function()
            local remote = {major = 1, minor = 2, patch = 3}
            local local_ = {major = 1, minor = 2, patch = 4}
            assert.is_false(Updater:_isNewer(remote, local_))
        end)

        it("returns false when remote is nil", function()
            local local_ = {major = 1, minor = 0, patch = 0}
            assert.is_false(Updater:_isNewer(nil, local_))
        end)

        it("returns false when local is nil", function()
            local remote = {major = 1, minor = 0, patch = 0}
            assert.is_false(Updater:_isNewer(remote, nil))
        end)

        it("returns false when both are nil", function()
            assert.is_false(Updater:_isNewer(nil, nil))
        end)
    end)

    describe("_getChangelog", function()

        it("returns empty string when body is nil", function()
            assert.are.equal("", Updater:_getChangelog({body = nil}))
        end)

        it("returns empty string when body is empty", function()
            assert.are.equal("", Updater:_getChangelog({body = ""}))
        end)

        it("returns body as-is when short", function()
            local body = "Fixed a bug in file upload."
            assert.are.equal(body, Updater:_getChangelog({body = body}))
        end)

        it("truncates body longer than 500 characters", function()
            local long_body = string.rep("x", 600)
            local result = Updater:_getChangelog({body = long_body})
            -- Should be 500 chars + "..."
            assert.are.equal(503, #result)
            assert.is_truthy(result:match("%.%.%.$"))
        end)
    end)

    describe("_getDownloadUrl", function()

        it("returns zip asset URL when available", function()
            local release = {
                assets = {
                    {name = "filesync.koplugin.zip", browser_download_url = "https://example.com/plugin.zip"},
                },
                zipball_url = "https://example.com/zipball",
            }
            assert.are.equal("https://example.com/plugin.zip", Updater:_getDownloadUrl(release))
        end)

        it("falls back to zipball_url when no zip asset", function()
            local release = {
                assets = {
                    {name = "notes.txt", browser_download_url = "https://example.com/notes.txt"},
                },
                zipball_url = "https://example.com/zipball",
            }
            assert.are.equal("https://example.com/zipball", Updater:_getDownloadUrl(release))
        end)

        it("falls back to zipball_url when assets is empty", function()
            local release = {
                assets = {},
                zipball_url = "https://example.com/zipball",
            }
            assert.are.equal("https://example.com/zipball", Updater:_getDownloadUrl(release))
        end)

        it("returns nil when no zip asset and no zipball_url", function()
            local release = {
                assets = {},
            }
            assert.is_nil(Updater:_getDownloadUrl(release))
        end)
    end)
end)
