-- Stub lfs before requiring fileops, since fileops tries to load it at require-time.
-- We only need a minimal stub; the pure-logic helpers we test don't use lfs.
package.loaded["lfs"] = {
    attributes = function() return nil end,
    dir = function() return function() return nil end end,
}

local FileOps = require("filesync/fileops")

describe("filesync.fileops", function()

    describe("_resolvePath", function()

        before_each(function()
            FileOps:setRootDir("/mnt/us")
        end)

        it("resolves a simple relative path", function()
            local path, err = FileOps:_resolvePath("/books")
            assert.is_nil(err)
            assert.are.equal("/mnt/us/books", path)
        end)

        it("resolves root path", function()
            local path, err = FileOps:_resolvePath("/")
            assert.is_nil(err)
            assert.are.equal("/mnt/us", path)
        end)

        it("resolves nil as root", function()
            local path, err = FileOps:_resolvePath(nil)
            assert.is_nil(err)
            assert.are.equal("/mnt/us", path)
        end)

        it("resolves empty string as root", function()
            local path, err = FileOps:_resolvePath("")
            assert.is_nil(err)
            assert.are.equal("/mnt/us", path)
        end)

        it("blocks path traversal with ..", function()
            local path, err = FileOps:_resolvePath("/../etc/passwd")
            assert.is_nil(path)
            assert.is_truthy(err:find("traversal"))
        end)

        it("blocks path traversal with embedded ..", function()
            local path, err = FileOps:_resolvePath("/books/../../../etc")
            assert.is_nil(path)
            assert.is_truthy(err:find("traversal"))
        end)

        it("normalizes double slashes", function()
            local path, err = FileOps:_resolvePath("//books///test//")
            assert.is_nil(err)
            assert.are.equal("/mnt/us/books/test", path)
        end)

        it("strips leading and trailing whitespace", function()
            local path, err = FileOps:_resolvePath("  /books  ")
            assert.is_nil(err)
            assert.are.equal("/mnt/us/books", path)
        end)

        it("prepends slash if missing", function()
            local path, err = FileOps:_resolvePath("books/fiction")
            assert.is_nil(err)
            assert.are.equal("/mnt/us/books/fiction", path)
        end)

        it("removes trailing slash except for root", function()
            local path, err = FileOps:_resolvePath("/books/")
            assert.is_nil(err)
            assert.are.equal("/mnt/us/books", path)
        end)

        it("works with a different root_dir", function()
            FileOps:setRootDir("/home/user")
            local path, err = FileOps:_resolvePath("/documents")
            assert.is_nil(err)
            assert.are.equal("/home/user/documents", path)
        end)
    end)

    describe("_validateFilename", function()

        it("accepts a normal filename", function()
            local ok, err = FileOps:_validateFilename("book.epub")
            assert.is_true(ok)
            assert.is_nil(err)
        end)

        it("accepts a filename with spaces", function()
            local ok, err = FileOps:_validateFilename("my book.epub")
            assert.is_true(ok)
            assert.is_nil(err)
        end)

        it("accepts a filename with dots", function()
            local ok, err = FileOps:_validateFilename("archive.fb2.zip")
            assert.is_true(ok)
            assert.is_nil(err)
        end)

        it("rejects nil filename", function()
            local ok, err = FileOps:_validateFilename(nil)
            assert.is_false(ok)
            assert.is_truthy(err:find("Empty"))
        end)

        it("rejects empty string", function()
            local ok, err = FileOps:_validateFilename("")
            assert.is_false(ok)
            assert.is_truthy(err:find("Empty"))
        end)

        it("rejects filename with forward slash", function()
            local ok, err = FileOps:_validateFilename("path/file.txt")
            assert.is_false(ok)
            assert.is_truthy(err:find("Invalid characters"))
        end)

        it("rejects filename with null byte", function()
            local ok, err = FileOps:_validateFilename("file\0name")
            assert.is_false(ok)
            assert.is_truthy(err:find("Invalid characters"))
        end)

        it("rejects single dot", function()
            local ok, err = FileOps:_validateFilename(".")
            assert.is_false(ok)
            assert.is_truthy(err:find("Invalid filename"))
        end)

        it("rejects double dot", function()
            local ok, err = FileOps:_validateFilename("..")
            assert.is_false(ok)
            assert.is_truthy(err:find("Invalid filename"))
        end)

        it("rejects filename longer than 255 characters", function()
            local long_name = string.rep("a", 256)
            local ok, err = FileOps:_validateFilename(long_name)
            assert.is_false(ok)
            assert.is_truthy(err:find("too long"))
        end)

        it("accepts filename of exactly 255 characters", function()
            local name = string.rep("a", 255)
            local ok, err = FileOps:_validateFilename(name)
            assert.is_true(ok)
            assert.is_nil(err)
        end)
    end)

    describe("_formatSize", function()

        it("formats bytes", function()
            assert.are.equal("0 B", FileOps:_formatSize(0))
            assert.are.equal("512 B", FileOps:_formatSize(512))
            assert.are.equal("1023 B", FileOps:_formatSize(1023))
        end)

        it("formats kilobytes", function()
            assert.are.equal("1.0 KB", FileOps:_formatSize(1024))
            assert.are.equal("1.5 KB", FileOps:_formatSize(1536))
            assert.are.equal("10.0 KB", FileOps:_formatSize(10240))
        end)

        it("formats megabytes", function()
            assert.are.equal("1.0 MB", FileOps:_formatSize(1024 * 1024))
            assert.are.equal("5.0 MB", FileOps:_formatSize(5 * 1024 * 1024))
        end)

        it("formats gigabytes", function()
            assert.are.equal("1.0 GB", FileOps:_formatSize(1024 * 1024 * 1024))
            assert.are.equal("2.5 GB", FileOps:_formatSize(2.5 * 1024 * 1024 * 1024))
        end)
    end)

    describe("_getMimeType", function()

        it("returns correct MIME for epub", function()
            assert.are.equal("application/epub+zip", FileOps:_getMimeType("book.epub"))
        end)

        it("returns correct MIME for pdf", function()
            assert.are.equal("application/pdf", FileOps:_getMimeType("doc.pdf"))
        end)

        it("returns correct MIME for mobi", function()
            assert.are.equal("application/x-mobipocket-ebook", FileOps:_getMimeType("book.mobi"))
        end)

        it("returns correct MIME for txt", function()
            assert.are.equal("text/plain", FileOps:_getMimeType("readme.txt"))
        end)

        it("returns correct MIME for html", function()
            assert.are.equal("text/html", FileOps:_getMimeType("page.html"))
        end)

        it("returns correct MIME for htm", function()
            assert.are.equal("text/html", FileOps:_getMimeType("page.htm"))
        end)

        it("returns correct MIME for json", function()
            assert.are.equal("application/json", FileOps:_getMimeType("data.json"))
        end)

        it("returns correct MIME for png", function()
            assert.are.equal("image/png", FileOps:_getMimeType("image.png"))
        end)

        it("returns correct MIME for jpg", function()
            assert.are.equal("image/jpeg", FileOps:_getMimeType("photo.jpg"))
        end)

        it("returns correct MIME for jpeg", function()
            assert.are.equal("image/jpeg", FileOps:_getMimeType("photo.jpeg"))
        end)

        it("returns correct MIME for gif", function()
            assert.are.equal("image/gif", FileOps:_getMimeType("anim.gif"))
        end)

        it("returns correct MIME for svg", function()
            assert.are.equal("image/svg+xml", FileOps:_getMimeType("icon.svg"))
        end)

        it("returns correct MIME for zip", function()
            assert.are.equal("application/zip", FileOps:_getMimeType("archive.zip"))
        end)

        it("returns octet-stream for unknown extension", function()
            assert.are.equal("application/octet-stream", FileOps:_getMimeType("data.xyz"))
        end)

        it("returns octet-stream for no extension", function()
            assert.are.equal("application/octet-stream", FileOps:_getMimeType("Makefile"))
        end)
    end)

    describe("_getFileType", function()

        it("classifies epub as ebook", function()
            assert.are.equal("ebook", FileOps:_getFileType("book.epub"))
        end)

        it("classifies pdf as ebook", function()
            assert.are.equal("ebook", FileOps:_getFileType("doc.pdf"))
        end)

        it("classifies mobi as ebook", function()
            assert.are.equal("ebook", FileOps:_getFileType("book.mobi"))
        end)

        it("classifies azw3 as ebook", function()
            assert.are.equal("ebook", FileOps:_getFileType("book.azw3"))
        end)

        it("classifies cbz as ebook", function()
            assert.are.equal("ebook", FileOps:_getFileType("comic.cbz"))
        end)

        it("classifies txt as document", function()
            assert.are.equal("document", FileOps:_getFileType("readme.txt"))
        end)

        it("classifies html as document", function()
            assert.are.equal("document", FileOps:_getFileType("page.html"))
        end)

        it("classifies md as document", function()
            assert.are.equal("document", FileOps:_getFileType("notes.md"))
        end)

        it("classifies png as image", function()
            assert.are.equal("image", FileOps:_getFileType("photo.png"))
        end)

        it("classifies jpg as image", function()
            assert.are.equal("image", FileOps:_getFileType("photo.jpg"))
        end)

        it("classifies webp as image", function()
            assert.are.equal("image", FileOps:_getFileType("photo.webp"))
        end)

        it("classifies unknown extensions as file", function()
            assert.are.equal("file", FileOps:_getFileType("data.xyz"))
        end)

        it("classifies extensionless files as file", function()
            assert.are.equal("file", FileOps:_getFileType("Makefile"))
        end)
    end)

    describe("isExtensionSafe", function()

        it("returns true for epub", function()
            assert.is_true(FileOps:isExtensionSafe("book.epub"))
        end)

        it("returns true for pdf", function()
            assert.is_true(FileOps:isExtensionSafe("doc.pdf"))
        end)

        it("returns true for mobi", function()
            assert.is_true(FileOps:isExtensionSafe("book.mobi"))
        end)

        it("returns true for txt", function()
            assert.is_true(FileOps:isExtensionSafe("notes.txt"))
        end)

        it("returns true for jpg", function()
            assert.is_true(FileOps:isExtensionSafe("photo.jpg"))
        end)

        it("returns true for png", function()
            assert.is_true(FileOps:isExtensionSafe("image.png"))
        end)

        it("returns true for compound extension fb2.zip", function()
            assert.is_true(FileOps:isExtensionSafe("book.fb2.zip"))
        end)

        it("is case insensitive", function()
            assert.is_true(FileOps:isExtensionSafe("BOOK.EPUB"))
            assert.is_true(FileOps:isExtensionSafe("Photo.JPG"))
        end)

        it("returns false for unsafe extensions", function()
            assert.is_false(FileOps:isExtensionSafe("script.sh"))
            assert.is_false(FileOps:isExtensionSafe("program.exe"))
            assert.is_false(FileOps:isExtensionSafe("archive.tar.gz"))
        end)

        it("returns false for files without extension", function()
            assert.is_false(FileOps:isExtensionSafe("Makefile"))
        end)

        it("returns false for nil", function()
            assert.is_false(FileOps:isExtensionSafe(nil))
        end)
    end)
end)
