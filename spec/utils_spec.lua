local Utils = require("filesync/utils")

describe("filesync.utils", function()

    describe("getPluginDir", function()

        it("returns a string", function()
            local dir = Utils.getPluginDir()
            assert.is_string(dir)
        end)

        it("returns a non-empty path", function()
            local dir = Utils.getPluginDir()
            assert.is_truthy(#dir > 0)
        end)
    end)

    describe("shellEscape", function()

        it("wraps a simple string in single quotes", function()
            assert.are.equal("'hello'", Utils.shellEscape("hello"))
        end)

        it("handles nil input", function()
            assert.are.equal("''", Utils.shellEscape(nil))
        end)

        it("handles empty string", function()
            assert.are.equal("''", Utils.shellEscape(""))
        end)

        it("escapes single quotes", function()
            -- The expected output: 'it'\''s'
            -- Which in Lua string literal is: 'it'\\''s'
            assert.are.equal("'it'\\''s'", Utils.shellEscape("it's"))
        end)

        it("handles strings with spaces", function()
            assert.are.equal("'hello world'", Utils.shellEscape("hello world"))
        end)

        it("handles strings with double quotes", function()
            assert.are.equal("'say \"hi\"'", Utils.shellEscape('say "hi"'))
        end)

        it("handles strings with special shell characters", function()
            assert.are.equal("'$HOME'", Utils.shellEscape("$HOME"))
            assert.are.equal("'`cmd`'", Utils.shellEscape("`cmd`"))
            assert.are.equal("'foo;bar'", Utils.shellEscape("foo;bar"))
            assert.are.equal("'a|b'", Utils.shellEscape("a|b"))
        end)

        it("handles strings with multiple single quotes", function()
            assert.are.equal("'a'\\''b'\\''c'", Utils.shellEscape("a'b'c"))
        end)

        it("handles paths with spaces", function()
            assert.are.equal("'/mnt/us/my books/novel.epub'", Utils.shellEscape("/mnt/us/my books/novel.epub"))
        end)
    end)
end)
