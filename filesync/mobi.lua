--- MOBI/AZW3 binary header parser for the FileSync plugin.
--- Provides stateless utility functions for parsing PalmDB/MOBI/EXTH headers
--- and extracting cover images from MOBI, AZW, AZW3, PRC, and PDB files.
---
--- Reference: https://wiki.mobileread.com/wiki/MOBI

local Mobi = {}

--- MOBI/AZW3 extensions lookup
Mobi.EXTENSIONS = {
    mobi = true, azw = true, azw3 = true, prc = true, pdb = true,
}

--- Read a big-endian uint16 from a binary string at 1-based offset
local function read_uint16_be(data, offset)
    return string.byte(data, offset) * 256 + string.byte(data, offset + 1)
end

--- Read a big-endian uint32 from a binary string at 1-based offset
local function read_uint32_be(data, offset)
    return string.byte(data, offset) * 16777216 + string.byte(data, offset + 1) * 65536
           + string.byte(data, offset + 2) * 256 + string.byte(data, offset + 3)
end

--- Parse MOBI/AZW3 binary headers and extract metadata.
--- Reads the PalmDB header, MOBI header, and EXTH records to extract
--- title, author, and cover image location.
--- Reference: https://wiki.mobileread.com/wiki/MOBI
--- @param full_path string: absolute filesystem path to the MOBI/AZW3 file
--- @return table|nil: {title, author, has_cover, cover_record_index, num_records} or nil on failure
function Mobi.parseMobiMetadata(full_path)
    local ok, result = pcall(function()
        local f = io.open(full_path, "rb")
        if not f then return nil end

        -- Read first 64KB which covers all headers
        local header_data = f:read(65536)
        if not header_data or #header_data < 78 then
            f:close()
            return nil
        end

        -- PalmDB header: bytes 1-32 = database name (1-based in Lua)
        local pdb_name = header_data:sub(1, 32):match("^([^%z]+)") or ""

        -- Number of records: bytes 77-78 (1-based)
        local num_records = read_uint16_be(header_data, 77)
        if num_records < 1 then
            f:close()
            return nil
        end

        -- Record offset table starts at byte 79 (1-based). Each entry is 8 bytes.
        local record_table_start = 79
        if #header_data < record_table_start + num_records * 8 then
            f:close()
            return nil
        end

        -- Read first record offset
        local first_record_offset = read_uint32_be(header_data, record_table_start)

        -- We need to read the first record. If it's beyond our buffer, seek and read more.
        local record_data
        if first_record_offset + 4096 <= #header_data then
            -- First record is within our buffer; extract from there onward
            record_data = header_data:sub(first_record_offset + 1)
        else
            -- Seek to the first record and read enough data
            f:seek("set", first_record_offset)
            record_data = f:read(65536)
        end

        if not record_data or #record_data < 132 then
            f:close()
            return nil
        end

        -- PalmDOC header is first 16 bytes of the record.
        -- MOBI header starts at byte 17 (offset 16 within record, 1-based = 17)
        local mobi_start = 17

        -- Verify "MOBI" identifier at mobi_start
        local mobi_id = record_data:sub(mobi_start, mobi_start + 3)
        if mobi_id ~= "MOBI" then
            f:close()
            return nil
        end

        -- MOBI header length
        local mobi_header_length = read_uint32_be(record_data, mobi_start + 4)

        -- Full title offset and length (relative to record start, 0-based)
        -- At mobi_start + 84 and mobi_start + 88 (0-based offsets 84, 88 within MOBI header)
        local full_title_offset = read_uint32_be(record_data, mobi_start + 84)
        local full_title_length = read_uint32_be(record_data, mobi_start + 88)

        -- Check for EXTH by looking for the magic bytes directly after the MOBI header
        -- (the EXTH flags field at offset 0x80 is unreliable across format versions)
        local has_exth = false
        local exth_check_pos = mobi_start + mobi_header_length
        if exth_check_pos + 4 <= #record_data then
            has_exth = record_data:sub(exth_check_pos, exth_check_pos + 3) == "EXTH"
        end

        -- First image record index at mobi_start + 108
        local first_image_record = nil
        if #record_data >= mobi_start + 111 then
            first_image_record = read_uint32_be(record_data, mobi_start + 108)
        end

        -- If first_image_record is 0 or invalid, scan PDB records to find first image
        if not first_image_record or first_image_record == 0 or first_image_record >= num_records then
            -- Scan from the end backwards to find the first image record
            -- Images (JPEG/PNG/GIF) are typically the last records before FLIS/FCIS
            local img_records = {}
            for ri = num_records - 1, 1, -1 do
                local ri_offset_pos = record_table_start + (ri * 8)
                if ri_offset_pos + 4 <= #header_data then
                    local ri_offset = read_uint32_be(header_data, ri_offset_pos)
                    f:seek("set", ri_offset)
                    local magic = f:read(4)
                    if magic then
                        local b1, b2 = string.byte(magic, 1), string.byte(magic, 2)
                        if (b1 == 0xFF and b2 == 0xD8) or magic == "\137PNG" or magic:sub(1,3) == "GIF" then
                            table.insert(img_records, 1, ri)
                        else
                            if #img_records > 0 then break end -- stop once we pass the image block
                        end
                    end
                end
            end
            if #img_records > 0 then
                first_image_record = img_records[1]
            end
        end

        -- Extract the full title from the record
        local full_title = nil
        -- full_title_offset is relative to record start (0-based), convert to 1-based
        local title_start = full_title_offset + 1
        if full_title_length > 0 and full_title_length < 1024 and
           title_start + full_title_length - 1 <= #record_data then
            full_title = record_data:sub(title_start, title_start + full_title_length - 1)
        end

        -- Parse EXTH header if present
        local exth_title = nil
        local author = nil
        local cover_offset = nil
        local thumb_offset = nil

        if has_exth then
            -- EXTH header follows the MOBI header
            local exth_start = mobi_start + mobi_header_length
            if exth_start + 12 <= #record_data then
                local exth_id = record_data:sub(exth_start, exth_start + 3)
                if exth_id == "EXTH" then
                    local exth_record_count = read_uint32_be(record_data, exth_start + 8)

                    local pos = exth_start + 12
                    for _ = 1, exth_record_count do
                        if pos + 8 > #record_data then break end
                        local rec_type = read_uint32_be(record_data, pos)
                        local rec_length = read_uint32_be(record_data, pos + 4)
                        if rec_length < 8 then break end -- malformed

                        local data_length = rec_length - 8
                        local rec_data = nil
                        if data_length > 0 and pos + 7 + data_length <= #record_data then
                            rec_data = record_data:sub(pos + 8, pos + 7 + data_length)
                        end

                        if rec_type == 100 and rec_data then
                            -- Author
                            author = rec_data:gsub("^%s+", ""):gsub("%s+$", "")
                        elseif rec_type == 503 and rec_data then
                            -- Updated title (preferred)
                            exth_title = rec_data:gsub("^%s+", ""):gsub("%s+$", "")
                        elseif rec_type == 201 and rec_data and #rec_data >= 4 then
                            -- Cover offset (index relative to first image record)
                            cover_offset = read_uint32_be(rec_data, 1)
                        elseif rec_type == 202 and rec_data and #rec_data >= 4 then
                            -- Thumbnail offset
                            thumb_offset = read_uint32_be(rec_data, 1)
                        end

                        pos = pos + rec_length
                    end
                end
            end
        end

        f:close()

        -- Build result: prefer EXTH title > full title > PDB name
        local title = exth_title
        if (not title or title == "") and full_title and full_title ~= "" then
            title = full_title
        end
        if (not title or title == "") and pdb_name ~= "" then
            title = pdb_name:gsub("_", " ")
        end

        local meta = {}
        if title and title ~= "" then meta.title = title end
        if author and author ~= "" then meta.author = author end

        -- Compute cover record index (absolute PDB record number)
        if cover_offset and first_image_record then
            meta.has_cover = true
            meta.cover_record_index = first_image_record + cover_offset
        elseif thumb_offset and first_image_record then
            meta.has_cover = true
            meta.cover_record_index = first_image_record + thumb_offset
        end

        -- Store record info needed for cover extraction
        meta.num_records = num_records

        return meta
    end)

    if ok and result then
        return result
    end
    return nil
end

--- Extract cover image data from a MOBI/AZW3 file.
--- Returns image_data, content_type (or nil, error_message).
--- @param full_path string: absolute filesystem path to the MOBI/AZW3 file
--- @return string|nil: raw image data bytes
--- @return string|nil: MIME content type (e.g., "image/jpeg"), or error message if first return is nil
function Mobi.extractMobiCover(full_path)
    local ok, img_data, content_type = pcall(function()
        -- First parse metadata to find the cover record index
        local meta = Mobi.parseMobiMetadata(full_path)
        if not meta or not meta.has_cover or not meta.cover_record_index then
            return nil, nil
        end

        local cover_index = meta.cover_record_index
        local num_records = meta.num_records

        if cover_index < 0 or cover_index >= num_records then
            return nil, nil
        end

        local f = io.open(full_path, "rb")
        if not f then return nil, nil end

        -- Re-read the PDB header to get record offsets
        -- We need record_table_start (byte 79) and the cover record's offset
        f:seek("set", 76)
        local num_rec_bytes = f:read(2)
        if not num_rec_bytes or #num_rec_bytes < 2 then
            f:close()
            return nil, nil
        end

        -- Read the record offset table entries we need
        -- We need the offset for cover_index and cover_index+1 (to know record size)
        local record_table_file_offset = 78 -- 0-based file offset for record table
        local entry_offset = record_table_file_offset + cover_index * 8

        f:seek("set", entry_offset)
        -- Read this record's offset (4 bytes) + attributes (4 bytes) + next record's offset (4 bytes)
        local entry_data = f:read(12)
        if not entry_data or #entry_data < 4 then
            f:close()
            return nil, nil
        end

        local record_offset = read_uint32_be(entry_data, 1)

        -- Determine record size: difference to next record, or read to a limit
        local record_size
        if #entry_data >= 12 and cover_index + 1 < num_records then
            local next_offset = read_uint32_be(entry_data, 9)
            record_size = next_offset - record_offset
        else
            -- Last record or can't determine size: read up to 2MB (generous limit for cover)
            record_size = 2 * 1024 * 1024
        end

        -- Sanity check
        if record_size <= 0 or record_size > 5 * 1024 * 1024 then
            f:close()
            return nil, nil
        end

        -- Seek to the record and read the image data
        f:seek("set", record_offset)
        local data = f:read(record_size)
        f:close()

        if not data or #data < 4 then
            return nil, nil
        end

        -- Detect image type from magic bytes
        local ctype = "image/jpeg" -- default
        local b1, b2, b3, b4 = string.byte(data, 1, 4)
        if b1 == 0xFF and b2 == 0xD8 then
            ctype = "image/jpeg"
        elseif b1 == 0x89 and data:sub(2, 4) == "PNG" then
            ctype = "image/png"
        elseif data:sub(1, 4) == "GIF8" then
            ctype = "image/gif"
        elseif data:sub(1, 4) == "RIFF" and #data >= 12 and data:sub(9, 12) == "WEBP" then
            ctype = "image/webp"
        end

        return data, ctype
    end)

    if ok and img_data then
        return img_data, content_type
    end
    return nil, "Cannot extract cover from MOBI/AZW3"
end

return Mobi
