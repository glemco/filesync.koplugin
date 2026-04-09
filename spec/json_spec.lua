local JSON = require("filesync/json")

describe("filesync.json", function()

    describe("encode", function()

        it("encodes nil as null", function()
            assert.are.equal("null", JSON.encode(nil))
        end)

        it("encodes true", function()
            assert.are.equal("true", JSON.encode(true))
        end)

        it("encodes false", function()
            assert.are.equal("false", JSON.encode(false))
        end)

        it("encodes integers", function()
            assert.are.equal("42", JSON.encode(42))
            assert.are.equal("0", JSON.encode(0))
            assert.are.equal("-7", JSON.encode(-7))
        end)

        it("encodes floating-point numbers", function()
            assert.are.equal("3.14", JSON.encode(3.14))
        end)

        it("encodes NaN as 0", function()
            assert.are.equal("0", JSON.encode(0/0))
        end)

        it("encodes infinity as 0", function()
            assert.are.equal("0", JSON.encode(math.huge))
            assert.are.equal("0", JSON.encode(-math.huge))
        end)

        it("encodes a simple string", function()
            assert.are.equal('"hello"', JSON.encode("hello"))
        end)

        it("encodes an empty string", function()
            assert.are.equal('""', JSON.encode(""))
        end)

        it("escapes special characters in strings", function()
            local result = JSON.encode('line1\nline2')
            assert.are.equal('"line1\\nline2"', result)
        end)

        it("escapes backslash", function()
            assert.are.equal('"a\\\\b"', JSON.encode('a\\b'))
        end)

        it("escapes double quotes", function()
            assert.are.equal('"say \\"hi\\""', JSON.encode('say "hi"'))
        end)

        it("escapes tabs", function()
            assert.are.equal('"a\\tb"', JSON.encode("a\tb"))
        end)

        it("escapes forward slashes", function()
            assert.are.equal('"a\\/b"', JSON.encode("a/b"))
        end)

        it("escapes control characters as unicode escapes", function()
            -- ASCII 1 -> \u0001
            local result = JSON.encode(string.char(1))
            assert.are.equal('"\\u0001"', result)
        end)

        it("encodes an empty table as empty array", function()
            assert.are.equal("[]", JSON.encode({}))
        end)

        it("encodes a simple array", function()
            assert.are.equal("[1,2,3]", JSON.encode({1, 2, 3}))
        end)

        it("encodes a string array", function()
            assert.are.equal('["a","b"]', JSON.encode({"a", "b"}))
        end)

        it("encodes a simple object", function()
            -- Objects have non-deterministic key order, so parse back and compare
            local result = JSON.encode({name = "test"})
            local decoded = JSON.decode(result)
            assert.are.equal("test", decoded.name)
        end)

        it("encodes nested structures", function()
            local input = {items = {1, 2}, ok = true}
            local result = JSON.encode(input)
            local decoded = JSON.decode(result)
            assert.are.equal(true, decoded.ok)
            assert.are.equal(1, decoded.items[1])
            assert.are.equal(2, decoded.items[2])
        end)

        it("encodes mixed-type arrays", function()
            local result = JSON.encode({1, "two", true, false})
            local decoded = JSON.decode(result)
            assert.are.equal(1, decoded[1])
            assert.are.equal("two", decoded[2])
            assert.are.equal(true, decoded[3])
            assert.are.equal(false, decoded[4])
        end)

        it("encodes a function value as null", function()
            assert.are.equal("null", JSON.encode(function() end))
        end)
    end)

    describe("decode", function()

        it("returns nil for nil input", function()
            assert.is_nil(JSON.decode(nil))
        end)

        it("returns nil for empty string input", function()
            assert.is_nil(JSON.decode(""))
        end)

        it("decodes null to nil", function()
            assert.is_nil(JSON.decode("null"))
        end)

        it("decodes true", function()
            assert.are.equal(true, JSON.decode("true"))
        end)

        it("decodes false", function()
            assert.are.equal(false, JSON.decode("false"))
        end)

        it("decodes integers", function()
            assert.are.equal(42, JSON.decode("42"))
            assert.are.equal(0, JSON.decode("0"))
            assert.are.equal(-7, JSON.decode("-7"))
        end)

        it("decodes floating-point numbers", function()
            assert.are.equal(3.14, JSON.decode("3.14"))
        end)

        it("decodes scientific notation", function()
            assert.are.equal(1e10, JSON.decode("1e10"))
            assert.are.equal(2.5e-3, JSON.decode("2.5e-3"))
            assert.are.equal(1E+2, JSON.decode("1E+2"))
        end)

        it("decodes a simple string", function()
            assert.are.equal("hello", JSON.decode('"hello"'))
        end)

        it("decodes an empty string", function()
            assert.are.equal("", JSON.decode('""'))
        end)

        it("decodes escaped characters in strings", function()
            assert.are.equal("a\nb", JSON.decode('"a\\nb"'))
            assert.are.equal("a\tb", JSON.decode('"a\\tb"'))
            assert.are.equal("a\\b", JSON.decode('"a\\\\b"'))
            assert.are.equal('a"b', JSON.decode('"a\\"b"'))
            assert.are.equal("a/b", JSON.decode('"a\\/b"'))
        end)

        it("decodes unicode escapes for ASCII range", function()
            assert.are.equal("A", JSON.decode('"\\u0041"'))
        end)

        it("decodes an empty array", function()
            local result = JSON.decode("[]")
            assert.are.same({}, result)
        end)

        it("decodes a simple array", function()
            local result = JSON.decode("[1,2,3]")
            assert.are.same({1, 2, 3}, result)
        end)

        it("decodes an empty object", function()
            local result = JSON.decode("{}")
            assert.are.same({}, result)
        end)

        it("decodes a simple object", function()
            local result = JSON.decode('{"name":"test","value":42}')
            assert.are.equal("test", result.name)
            assert.are.equal(42, result.value)
        end)

        it("decodes nested objects and arrays", function()
            local json_str = '{"items":[1,2,3],"meta":{"ok":true}}'
            local result = JSON.decode(json_str)
            assert.are.same({1, 2, 3}, result.items)
            assert.are.equal(true, result.meta.ok)
        end)

        it("handles whitespace around values", function()
            local result = JSON.decode('  { "a" : 1 , "b" : [ 2 , 3 ] }  ')
            assert.are.equal(1, result.a)
            assert.are.same({2, 3}, result.b)
        end)

        it("returns nil for malformed JSON (missing closing brace)", function()
            assert.is_nil(JSON.decode('{"a":1'))
        end)

        it("returns nil for malformed JSON (trailing comma in object)", function()
            assert.is_nil(JSON.decode('{"a":1,}'))
        end)

        it("is lenient with trailing comma in array (parser quirk)", function()
            -- The recursive descent parser happens to accept trailing commas
            -- because parse_value returns nil for ']' and table.insert with nil is a no-op.
            local result = JSON.decode('[1,2,]')
            assert.are.same({1, 2}, result)
        end)

        it("returns nil for completely invalid input", function()
            assert.is_nil(JSON.decode("not json at all"))
        end)
    end)

    describe("encode/decode round-trip", function()

        it("round-trips strings", function()
            local original = "hello world"
            assert.are.equal(original, JSON.decode(JSON.encode(original)))
        end)

        it("round-trips numbers", function()
            assert.are.equal(42, JSON.decode(JSON.encode(42)))
            assert.are.equal(3.14, JSON.decode(JSON.encode(3.14)))
            assert.are.equal(-100, JSON.decode(JSON.encode(-100)))
        end)

        it("round-trips booleans", function()
            assert.are.equal(true, JSON.decode(JSON.encode(true)))
            assert.are.equal(false, JSON.decode(JSON.encode(false)))
        end)

        it("round-trips arrays", function()
            local original = {1, "two", true, false}
            local result = JSON.decode(JSON.encode(original))
            assert.are.equal(1, result[1])
            assert.are.equal("two", result[2])
            assert.are.equal(true, result[3])
            assert.are.equal(false, result[4])
        end)

        it("round-trips nested structures", function()
            local original = {name = "test", tags = {"a", "b"}, count = 5}
            local result = JSON.decode(JSON.encode(original))
            assert.are.equal("test", result.name)
            assert.are.same({"a", "b"}, result.tags)
            assert.are.equal(5, result.count)
        end)

        it("round-trips strings with special characters", function()
            local original = 'line1\nline2\ttab "quoted" back\\slash'
            assert.are.equal(original, JSON.decode(JSON.encode(original)))
        end)

        it("round-trips large numbers", function()
            local original = 999999999999
            assert.are.equal(original, JSON.decode(JSON.encode(original)))
        end)
    end)

    describe("escapeString", function()

        it("passes through plain ASCII", function()
            assert.are.equal("hello", JSON.escapeString("hello"))
        end)

        it("escapes backspace", function()
            assert.are.equal("\\b", JSON.escapeString("\b"))
        end)

        it("escapes form feed", function()
            assert.are.equal("\\f", JSON.escapeString("\f"))
        end)

        it("escapes carriage return", function()
            assert.are.equal("\\r", JSON.escapeString("\r"))
        end)

        it("preserves multi-byte UTF-8 sequences byte-by-byte", function()
            -- The encoder works byte-by-byte, so multi-byte UTF-8 chars
            -- (all bytes >= 0x80) pass through unchanged
            local utf8_str = "\xC3\xA9"  -- e-acute in UTF-8
            assert.are.equal(utf8_str, JSON.escapeString(utf8_str))
        end)
    end)
end)
