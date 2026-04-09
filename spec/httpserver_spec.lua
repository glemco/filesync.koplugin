-- Stub heavy KOReader dependencies that httpserver.lua requires at load time
package.loaded["socket"] = {
    bind = function() return nil, "stub" end,
}
package.loaded["ui/uimanager"] = {
    scheduleIn = function() end,
    show = function() end,
}

local HttpServer = require("filesync/httpserver")

-- Create a fresh instance for testing so we don't pollute the module table
local function new_server()
    return HttpServer:new()
end

describe("filesync.httpserver", function()

    describe("_urlDecode", function()
        local server

        before_each(function()
            server = new_server()
        end)

        it("decodes a plain string unchanged", function()
            assert.are.equal("hello", server:_urlDecode("hello"))
        end)

        it("decodes plus as space", function()
            assert.are.equal("hello world", server:_urlDecode("hello+world"))
        end)

        it("decodes percent-encoded characters", function()
            assert.are.equal("hello world", server:_urlDecode("hello%20world"))
        end)

        it("decodes slash encoding", function()
            assert.are.equal("/path/to/file", server:_urlDecode("%2Fpath%2Fto%2Ffile"))
        end)

        it("decodes special characters", function()
            assert.are.equal("a&b=c", server:_urlDecode("a%26b%3Dc"))
        end)

        it("handles mixed encoding", function()
            assert.are.equal("hello world & goodbye", server:_urlDecode("hello+world+%26+goodbye"))
        end)

        it("handles empty string", function()
            assert.are.equal("", server:_urlDecode(""))
        end)

        it("passes through unencoded characters", function()
            assert.are.equal("abc123", server:_urlDecode("abc123"))
        end)

        it("decodes unicode percent sequences", function()
            -- %C3%A9 is UTF-8 for e-acute
            assert.are.equal("\xC3\xA9", server:_urlDecode("%C3%A9"))
        end)
    end)

    describe("_parseQuery", function()
        local server

        before_each(function()
            server = new_server()
        end)

        it("returns empty table for nil", function()
            assert.are.same({}, server:_parseQuery(nil))
        end)

        it("returns empty table for empty string", function()
            assert.are.same({}, server:_parseQuery(""))
        end)

        it("parses a single key-value pair", function()
            local result = server:_parseQuery("key=value")
            assert.are.equal("value", result.key)
        end)

        it("parses multiple key-value pairs", function()
            local result = server:_parseQuery("a=1&b=2&c=3")
            assert.are.equal("1", result.a)
            assert.are.equal("2", result.b)
            assert.are.equal("3", result.c)
        end)

        it("decodes percent-encoded keys and values", function()
            local result = server:_parseQuery("path=%2Fbooks%2Fnovel.epub")
            assert.are.equal("/books/novel.epub", result.path)
        end)

        it("decodes plus signs in values", function()
            local result = server:_parseQuery("filter=my+book")
            assert.are.equal("my book", result.filter)
        end)

        it("handles key with empty value", function()
            local result = server:_parseQuery("key=")
            assert.are.equal("", result.key)
        end)

        it("handles key without equals sign", function()
            local result = server:_parseQuery("flag")
            assert.are.equal("", result.flag)
        end)

        it("parses a realistic files API query", function()
            local result = server:_parseQuery("path=%2F&sort=name&order=asc&filter=")
            assert.are.equal("/", result.path)
            assert.are.equal("name", result.sort)
            assert.are.equal("asc", result.order)
            assert.are.equal("", result.filter)
        end)
    end)
end)
