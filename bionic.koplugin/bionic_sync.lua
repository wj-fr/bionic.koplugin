--[[
Annotation sync between the original book and its bionic copy.

Why this is needed: KOReader stores highlights as crengine XPointers (DOM path + character offset).
The bionic copy has extra <b>/<span> nodes and split text nodes, so an XPointer from one rendering
means nothing in the other. The plain text is identical, though, so a position is carried over as

        (spine item, number of NON-WHITESPACE characters before it)

which does not depend on any markup and not on how whitespace is collapsed. This module
  * parses the (X)HTML of a spine item into the same node tree crengine builds (text nodes, whitespace
    collapsing, dropped blank nodes, same-name sibling indexes), so that XPointers can be read
    (xpointer -> count) and written (count -> xpointer);
  * converts a KOReader annotation item from one rendering to the other and VERIFIES the result against
    the highlighted text, so a wrong position is never written;
  * reconciles two annotation lists (adds, edits, deletions) using a snapshot of the last sync.

Everything here is plain Lua apart from Book:open(), which needs ffi/archiver.
]]

local Sync = {}

--------------------------------------------------------------------------
-- UTF-8 helpers (LuaJIT has no utf8 library)
--------------------------------------------------------------------------

local function ulen(s)
    local _, cont = s:gsub("[\128-\191]", "")
    return #s - cont
end

-- byte index where code point number k (0-based) starts; #s + 1 when k is past the end
local function cp_to_byte(s, k)
    if k <= 0 then return 1 end
    if not s:find("[\128-\255]") then return k + 1 end
    local pos, n, len = 1, 0, #s
    while n < k and pos <= len do
        local c = s:byte(pos)
        pos = pos + (c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or 4)
        n = n + 1
    end
    return pos
end

local function usub(s, i, j) -- code points i..j-1 (0-based, j exclusive)
    return s:sub(cp_to_byte(s, i), cp_to_byte(s, j) - 1)
end

local function utf8char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
    if cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
    end
    return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64,
        0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

-- non-whitespace characters only (collapsible whitespace: space, tab, CR, LF)
local function strip_ws(s) return (s:gsub("[ \t\r\n]", "")) end

-- what two texts are compared by: no whitespace, no soft hyphens / zero-width characters
local function norm(s)
    s = s:gsub("[ \t\r\n]", "")
    s = s:gsub("\194\173", "")           -- U+00AD soft hyphen
    s = s:gsub("\226\128[\139-\141]", "") -- U+200B..U+200D
    s = s:gsub("\239\187\191", "")        -- U+FEFF
    return s
end
Sync.norm = norm

--------------------------------------------------------------------------
-- Entities
--------------------------------------------------------------------------

local ENT = { amp = 38, lt = 60, gt = 62, quot = 34, apos = 39 }
do
    local latin1 = ([[nbsp iexcl cent pound curren yen brvbar sect uml copy ordf laquo not shy reg macr deg
        plusmn sup2 sup3 acute micro para middot cedil sup1 ordm raquo frac14 frac12 frac34 iquest Agrave Aacute
        Acirc Atilde Auml Aring AElig Ccedil Egrave Eacute Ecirc Euml Igrave Iacute Icirc Iuml ETH Ntilde Ograve
        Oacute Ocirc Otilde Ouml times Oslash Ugrave Uacute Ucirc Uuml Yacute THORN szlig agrave aacute acirc
        atilde auml aring aelig ccedil egrave eacute ecirc euml igrave iacute icirc iuml eth ntilde ograve oacute
        ocirc otilde ouml divide oslash ugrave uacute ucirc uuml yacute thorn yuml]])
    local cp = 160
    for name in latin1:gmatch("%S+") do ENT[name] = cp; cp = cp + 1 end
    local more = { ndash = 8211, mdash = 8212, lsquo = 8216, rsquo = 8217, sbquo = 8218, ldquo = 8220,
        rdquo = 8221, bdquo = 8222, dagger = 8224, Dagger = 8225, bull = 8226, hellip = 8230, permil = 8240,
        prime = 8242, Prime = 8243, lsaquo = 8249, rsaquo = 8250, euro = 8364, trade = 8482, larr = 8592,
        uarr = 8593, rarr = 8594, darr = 8595, harr = 8596, minus = 8722, ensp = 8194, emsp = 8195,
        thinsp = 8201, zwnj = 8204, zwj = 8205, lrm = 8206, rlm = 8207, OElig = 338, oelig = 339,
        Scaron = 352, scaron = 353, Yuml = 376, fnof = 402, circ = 710, tilde = 732, infin = 8734,
        ne = 8800, le = 8804, ge = 8805, hearts = 9829, loz = 9674, spades = 9824, clubs = 9827,
        diams = 9830, sum = 8721, radic = 8730, asymp = 8776, part = 8706, nabla = 8711, isin = 8712,
        prod = 8719, lang = 9001, rang = 9002 }
    for k, v in pairs(more) do ENT[k] = v end
end

-- returns the decoded string, or nil + the unknown entity
local function decode_entities(s)
    if not s:find("&", 1, true) then return s end
    local bad
    local out = s:gsub("&(#?[%w]+);", function(e)
        if e:sub(1, 1) == "#" then
            local n
            if e:sub(2, 2) == "x" or e:sub(2, 2) == "X" then n = tonumber(e:sub(3), 16) else n = tonumber(e:sub(2)) end
            if n and n > 0 and n < 0x110000 then return utf8char(n) end
            bad = bad or e
            return nil
        end
        local cp = ENT[e]
        if cp then return utf8char(cp) end
        bad = bad or e
        return nil
    end)
    if bad then return nil, bad end
    return out
end

--------------------------------------------------------------------------
-- HTML -> node tree (the way crengine builds it)
--------------------------------------------------------------------------

local VOID = {}
for n in ("br img hr meta link input col area base param wbr source track embed"):gmatch("%S+") do VOID[n] = true end

-- elements crengine treats as blocks when it decides whether a blank text node is kept
local BLOCK = {}
for n in ([[p div ul ol li dl dt dd blockquote h1 h2 h3 h4 h5 h6 pre hr table tr td th tbody thead tfoot
    caption section article aside figure figcaption header footer nav center address form fieldset legend
    main hgroup details summary menu dir code body html]]):gmatch("%S+") do BLOCK[n] = true end

local RAW = { script = true, style = true } -- content is not text

-- text directly inside these is invalid markup that crengine rewrites: positions there are not modelled
local NO_TEXT = { table = true, tbody = true, thead = true, tfoot = true, tr = true }

local function new_node(tag, parent)
    return { tag = tag, parent = parent, kids = {}, cnt = {} }
end

-- Returns the tree: { root = body node, texts = {text nodes in order}, total = non-blank chars }
-- or nil + reason.
function Sync.parse(html)
    local body_start = html:find("<[Bb][Oo][Dd][Yy][%s>/]")
    if not body_start then return nil, "no body" end
    local pos = body_start
    local len = #html
    local root
    local cur
    local texts, running = {}, 0
    local pre_depth = 0
    local raw_until

    local function add_child(parent, node)
        local kids = parent.kids
        kids[#kids + 1] = node
        local key = node.tag or "text()"
        local c = (parent.cnt[key] or 0) + 1
        parent.cnt[key] = c
        node.k = c
    end

    local function add_text(s, literal)
        if s == "" or not cur then return true end
        if not literal then
            local dec, bad = decode_entities(s)
            if not dec then return nil, "entity " .. tostring(bad) end
            s = dec
        end
        if pre_depth == 0 then
            s = s:gsub("[ \t\r\n]+", " ")
            if s == " " then
                -- a blank node at the start of a block, or right after a block, is dropped; between
                -- inline content (also at the start of an inline element) it is kept
                local prev = cur.kids[#cur.kids]
                if prev == nil then
                    if BLOCK[cur.tag] then return true end
                elseif prev.tag and BLOCK[prev.tag] then
                    return true
                end
            end
        end
        if NO_TEXT[cur.tag] and strip_ws(s) ~= "" then return nil, "text directly in <" .. cur.tag .. ">" end
        local node = { s = s, parent = cur, nwsb = running }
        local nw = strip_ws(s)
        node.n = ulen(nw)
        node.cpl = ulen(s)
        running = running + node.n
        add_child(cur, node)
        texts[#texts + 1] = node
        return true
    end

    while pos <= len do
        local lt = html:find("<", pos, true)
        if not lt then break end
        if lt > pos and not raw_until then
            local ok, err = add_text(html:sub(pos, lt - 1))
            if not ok then return nil, err end
        end
        if html:sub(lt, lt + 3) == "<!--" then
            local e = html:find("-->", lt + 4, true)
            if not e then return nil, "unterminated comment" end
            pos = e + 3
        elseif html:sub(lt, lt + 8) == "<![CDATA[" then
            local e = html:find("]]>", lt + 9, true)
            if not e then return nil, "unterminated cdata" end
            -- CDATA is literal text (no entities) but still a text node of its own
            local ok, err = add_text(html:sub(lt + 9, e - 1), true)
            if not ok then return nil, err end
            pos = e + 3
        elseif html:sub(lt, lt + 1) == "<?" then
            local e = html:find("?>", lt + 2, true)
            if not e then return nil, "unterminated pi" end
            pos = e + 2
        elseif html:sub(lt, lt + 1) == "<!" then
            local e = html:find(">", lt + 2, true)
            if not e then return nil, "unterminated declaration" end
            pos = e + 1
        elseif html:sub(lt, lt + 1) == "</" then
            local e = html:find(">", lt + 2, true)
            if not e then return nil, "unterminated end tag" end
            local name = html:sub(lt + 2, e - 1):match("^%s*([^%s>]+)")
            name = name and name:lower()
            pos = e + 1
            if raw_until then
                if name == raw_until then raw_until = nil; cur = cur and cur.parent or cur end
            elseif name and not VOID[name] then
                if not cur or cur.tag ~= name then return nil, "mismatched </" .. tostring(name) .. ">" end
                if name == "pre" then pre_depth = pre_depth - 1 end
                if cur == root then
                    return { root = root, texts = texts, total = running }
                end
                cur = cur.parent
            end
        else
            -- start tag: find its end, honouring quotes
            local i = lt + 1
            local name = html:match("^([%w:_%-%.]+)", i)
            if not name then
                -- a stray "<" in the text
                if not raw_until then
                    local ok, err = add_text("<", true)
                    if not ok then return nil, err end
                end
                pos = lt + 1
            else
                name = name:lower()
                i = i + #name
                local selfclose = false
                while true do
                    local c = html:sub(i, i)
                    if c == "" then return nil, "unterminated tag" end
                    if c == ">" then break end
                    if c == "/" and html:sub(i + 1, i + 1) == ">" then selfclose = true; i = i + 1; break end
                    if c == '"' or c == "'" then
                        local q = html:find(c, i + 1, true)
                        if not q then return nil, "unterminated attribute" end
                        i = q + 1
                    else
                        i = i + 1
                    end
                end
                pos = i + 1
                if not raw_until then
                    local node = new_node(name, cur)
                    node.nwsb = running
                    if cur then add_child(cur, node) else root = node end
                    if name == "body" and cur == nil then
                        cur = node
                    elseif not cur then
                        return nil, "content before body"
                    elseif VOID[name] or selfclose then
                        -- empty element
                    else
                        if RAW[name] then raw_until = name end
                        if name == "pre" then pre_depth = pre_depth + 1 end
                        cur = node
                    end
                    if name == "body" and selfclose then return { root = root, texts = texts, total = running } end
                end
            end
        end
    end
    if root and cur == root then
        -- no closing </body>: accept what was read
        return { root = root, texts = texts, total = running }
    end
    return nil, "unterminated document"
end

--------------------------------------------------------------------------
-- XPointer <-> position
--------------------------------------------------------------------------

local function nws_in(s, off) -- non-blank characters among the first `off` code points of s
    if off <= 0 then return 0 end
    return ulen(strip_ws(s:sub(1, cp_to_byte(s, off) - 1)))
end

-- Returns fragment index, nws count  |  nil, reason.   `trees(frag)` gives the parsed tree.
function Sync.xp_to_pos(xp, trees)
    if type(xp) ~= "string" then return nil, "not an xpointer" end
    local pre = "/body/DocFragment"
    if xp:sub(1, #pre) ~= pre then return nil, "unknown xpointer" end
    local rest = xp:sub(#pre + 1)
    local frag = 1
    local idx = rest:match("^%[(%d+)%]")
    if idx then frag = tonumber(idx); rest = rest:gsub("^%[%d+%]", "", 1) end
    if rest:sub(1, 5) ~= "/body" then return nil, "unknown xpointer" end
    local tree, err = trees(frag)
    if not tree then return nil, err or "no such spine item" end
    local node = tree.root
    local off
    local segs = {}
    for seg in rest:sub(7):gmatch("[^/]+") do segs[#segs + 1] = seg end
    for si, seg in ipairs(segs) do
        if si == #segs then
            local base, o = seg:match("^(.-)%.(%d+)$")
            if base then seg = base; off = tonumber(o) end
        end
        local name, k = seg:match("^(.-)%[(%d+)%]$")
        if not name then name, k = seg, 1 else k = tonumber(k) end
        name = name:lower()
        local is_text = name == "text()"
        local found, seen = nil, 0
        for _i, kid in ipairs(node.kids) do
            if (is_text and kid.tag == nil) or (not is_text and kid.tag == name) then
                seen = seen + 1
                if seen == k then found = kid; break end
            end
        end
        if not found then return nil, "path not found" end
        node = found
    end
    if node.tag == nil then
        return frag, node.nwsb + nws_in(node.s, off or 0)
    end
    return frag, node.nwsb -- an element: its start
end

local function seg_name(node)
    local key = node.tag or "text()"
    local total = node.parent.cnt[key]
    if total > 1 then return key .. "[" .. node.k .. "]" end
    return key
end

-- locate the text node holding the character with 0-based index c; binary search
local function text_at(tree, c)
    local texts = tree.texts
    local lo, hi = 1, #texts
    local found
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local t = texts[mid]
        if c < t.nwsb then
            hi = mid - 1
        elseif c >= t.nwsb + t.n then
            lo = mid + 1
        else
            found = t; break
        end
    end
    return found
end

-- local code-point offset (0-based) of the j-th (0-based) non-blank character of s
local function offset_of_nws(s, j)
    local count, off = 0, 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if ch ~= " " and ch ~= "\t" and ch ~= "\r" and ch ~= "\n" then
            if count == j then return off end
            count = count + 1
        end
        off = off + 1
    end
    return off
end

-- Returns an xpointer for the position `c` (non-blank characters before it) in spine item `frag`.
-- prefer "start": the position just before character c (word start); "end": just after character c-1.
-- nfrag: number of spine items (the DocFragment index is only written when there are several).
function Sync.pos_to_xp(tree, frag, nfrag, c, prefer)
    local node, off
    if tree.total == 0 then return nil, "no text" end
    if c > tree.total then c = tree.total end
    if c < 0 then c = 0 end
    if prefer == "end" and c > 0 then
        local t = text_at(tree, c - 1)
        if not t then return nil, "no text node" end
        node, off = t, offset_of_nws(t.s, c - 1 - t.nwsb) + 1
    else
        local t = text_at(tree, c)
        if t then
            node, off = t, offset_of_nws(t.s, c - t.nwsb)
        else -- c == total: the very end
            local t2 = text_at(tree, c - 1)
            if not t2 then return nil, "no text node" end
            node, off = t2, offset_of_nws(t2.s, c - 1 - t2.nwsb) + 1
        end
    end
    local parts = {}
    local n = node
    while n.parent do
        table.insert(parts, 1, seg_name(n))
        n = n.parent
    end
    -- n is now the body root
    local head = "/body/DocFragment" .. (nfrag > 1 and ("[" .. frag .. "]") or "") .. "/body"
    local path = #parts > 0 and (head .. "/" .. table.concat(parts, "/")) or head
    return path .. "." .. off
end

-- the non-blank text between two counts of a tree
function Sync.slice(tree, c0, c1)
    if c1 <= c0 then return "" end
    local out = {}
    local t = text_at(tree, c0)
    local texts = tree.texts
    local i
    if t then
        for k = 1, #texts do if texts[k] == t then i = k; break end end
    end
    if not i then return "" end
    for k = i, #texts do
        local node = texts[k]
        if node.nwsb >= c1 then break end
        if node.n > 0 then
            local nw = node.nw
            if not nw then nw = strip_ws(node.s); node.nw = nw end
            local from = math.max(c0 - node.nwsb, 0)
            local to = math.min(c1 - node.nwsb, node.n)
            out[#out + 1] = usub(nw, from, to)
        end
    end
    return table.concat(out)
end

-- all text nodes joined, for searching
local function flat_text(tree)
    if tree.flat then return tree.flat end
    local out = {}
    for _i, node in ipairs(tree.texts) do
        if node.n > 0 then
            local nw = node.nw
            if not nw then nw = strip_ws(node.s); node.nw = nw end
            out[#out + 1] = nw
        end
    end
    tree.flat = table.concat(out)
    return tree.flat
end

--------------------------------------------------------------------------
-- A book: spine -> spine item trees
--------------------------------------------------------------------------

local Book = {}
Book.__index = Book

local function url_decode(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function dirname(p) return p:match("^(.*)/[^/]*$") or "" end

local function resolve_path(base_dir, href)
    href = url_decode(href:gsub("#.*$", ""))
    local full = base_dir ~= "" and (base_dir .. "/" .. href) or href
    local out = {}
    for seg in full:gmatch("[^/]+") do
        if seg == ".." then table.remove(out) elseif seg ~= "." then out[#out + 1] = seg end
    end
    return table.concat(out, "/")
end

local function attr(tag, name)
    return tag:match("%f[%w]" .. name .. "%s*=%s*\"([^\"]*)\"") or tag:match("%f[%w]" .. name .. "%s*=%s*'([^']*)'")
end

-- Opens an EPUB (or an already open reader with :extractToMemory). Returns a Book or nil + reason.
function Sync.open_book(path_or_reader)
    local reader, owned = path_or_reader, false
    if type(path_or_reader) == "string" then
        local ok, Archiver = pcall(require, "ffi/archiver")
        if not ok then return nil, "no archiver" end
        reader = Archiver.Reader:new()
        if not reader:open(path_or_reader) then return nil, "cannot open" end
        owned = true
        -- the reader only knows the entry names after one pass over the archive
        for _entry in reader:iterate() do end
    end
    local self = setmetatable({ reader = reader, owned = owned, cache = {}, fails = {} }, Book)
    local container = reader:extractToMemory("META-INF/container.xml")
    if not container then self:close(); return nil, "no container.xml" end
    local opf_path = container:match("full%-path%s*=%s*\"([^\"]+)\"") or container:match("full%-path%s*=%s*'([^']+)'")
    if not opf_path then self:close(); return nil, "no opf" end
    opf_path = url_decode(opf_path)
    local opf = reader:extractToMemory(opf_path)
    if not opf then self:close(); return nil, "cannot read opf" end
    local base = dirname(opf_path)
    local manifest = {}
    for tag in opf:gmatch("<[%w:]*item%s[^>]*>") do
        local id, href, mt = attr(tag, "id"), attr(tag, "href"), attr(tag, "media%-type")
        if id and href then manifest[id] = { href = href, mt = mt or "" } end
    end
    self.files = {}
    for tag in opf:gmatch("<[%w:]*itemref%s[^>]*>") do
        local idref = attr(tag, "idref")
        local m = idref and manifest[idref]
        if m and (m.mt:find("html", 1, true) or m.mt:find("xml", 1, true)) then
            self.files[#self.files + 1] = resolve_path(base, m.href)
        end
    end
    self.nfrag = #self.files
    if self.nfrag == 0 then self:close(); return nil, "empty spine" end
    return self
end

function Book:close()
    if self.owned and self.reader then pcall(self.reader.close, self.reader) end
    self.reader = nil
    self.cache = {}
end

-- parsed tree of spine item n (cached); nil + reason on failure
function Book:tree(n)
    local c = self.cache[n]
    if c then return c end
    if self.fails[n] then return nil, self.fails[n] end
    local path = self.files[n]
    if not path then return nil, "no such spine item" end
    local data = self.reader and self.reader:extractToMemory(path)
    if not data then self.fails[n] = "cannot read " .. path; return nil, self.fails[n] end
    local head = data:sub(1, 600):lower()
    local enc = head:match("encoding%s*=%s*[\"']([^\"']+)") or head:match("charset%s*=%s*([%w%-_]+)")
    if enc and enc ~= "utf-8" and enc ~= "utf8" then
        self.fails[n] = "unsupported encoding " .. enc
        return nil, self.fails[n]
    end
    local tree, err = Sync.parse(data)
    if not tree then self.fails[n] = "parse error: " .. tostring(err); return nil, self.fails[n] end
    self.cache[n] = tree
    return tree
end

function Book:trees_fn()
    return function(n) return self:tree(n) end
end

--------------------------------------------------------------------------
-- Converting one annotation item
--------------------------------------------------------------------------

local function copy(v, depth)
    if type(v) ~= "table" then return v end
    depth = depth or 0
    if depth > 12 then return nil end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x, depth + 1) end
    return out
end
Sync.copy = copy

local function is_xp(v) return type(v) == "string" and v:sub(1, 1) == "/" end

-- Does the highlighted text (as KOReader stored it) match this position range? true / false / nil (cannot tell)
local function text_matches(item, tree, c0, c1)
    if item.text_edited or type(item.text) ~= "string" or item.text == "" then return nil end
    local want = norm(item.text)
    if want == "" then return nil end
    return norm(Sync.slice(tree, c0, c1)) == want
end

-- Where does `want` occur in the flat text of the tree, closest to the expected start? returns start count
local function search_near(tree, want, expected)
    local flat = flat_text(tree)
    local best, best_dist
    local init = 1
    -- flat is UTF-8: work in bytes, then convert the match to a code point count
    while true do
        local s, e = flat:find(want, init, true)
        if not s then break end
        local cp = ulen(flat:sub(1, s - 1))
        local dist = math.abs(cp - expected)
        if best == nil or dist < best_dist then best, best_dist = cp, dist end
        init = e + 1 - (e - s) -- allow overlapping matches
        if init <= s then init = s + 1 end
    end
    return best
end

-- Converts item (made in rendering `src`, a Book) into the rendering `dst` (a Book).
-- Returns the new item, or nil + reason. The source item is not modified.
-- relaxed (manual import): when the position cannot be verified, look for the highlighted text itself
-- (near the expected place first, then anywhere in the book).
function Sync.convert_item(item, src, dst, relaxed)
    if type(item) ~= "table" then return nil, "bad item" end
    local src_trees = src:trees_fn()
    local is_range = is_xp(item.pos0) and is_xp(item.pos1)
    local f0, c0, f1, c1
    if is_range then
        f0, c0 = Sync.xp_to_pos(item.pos0, src_trees)
        if not f0 then return nil, "start position: " .. tostring(c0) end
        f1, c1 = Sync.xp_to_pos(item.pos1, src_trees)
        if not f1 then return nil, "end position: " .. tostring(c1) end
    elseif is_xp(item.page) then
        f0, c0 = Sync.xp_to_pos(item.page, src_trees)
        if not f0 then
            if not relaxed then return nil, "position: " .. tostring(c0) end
        end
        f1, c1 = f0, c0
    else
        return nil, "no position"
    end

    local out = copy(item)
    out.pageno, out.pageref = nil, nil -- KOReader recalculates them

    if not is_range then
        if not f0 then return nil, "position not found" end
        local dtree, derr = dst:tree(f0)
        if not dtree then return nil, derr end
        local x0, e0 = Sync.pos_to_xp(dtree, f0, dst.nfrag, c0, "start")
        if not x0 then return nil, e0 end
        out.page = x0
        return out
    end

    local dtree, derr = dst:tree(f0)
    if not dtree then return nil, derr end
    local stree = src:tree(f0)
    local same = f0 == f1
    local want = (type(item.text) == "string" and not item.text_edited) and norm(item.text) or ""

    -- 1) the position as it is in the source must really hold the highlighted text, otherwise the
    --    model of the source is wrong for this spot
    local src_ok
    if same then src_ok = text_matches(item, stree, c0, c1) end
    if src_ok == false and not relaxed then return nil, "position does not match the highlighted text" end

    -- 2) the same counts in the target must hold the same text
    local n0, n1, nf = c0, c1, f0
    local need_search = src_ok == false
    if same and not need_search and text_matches(item, dtree, n0, n1) == false then need_search = true end
    if need_search then
        if want == "" then return nil, "no text to search for" end
        local found = search_near(dtree, want, c0)
        if found then
            n0, n1 = found, found + ulen(want)
        elseif relaxed then
            for f = 1, dst.nfrag do
                if f ~= f0 then
                    local t = dst:tree(f)
                    local fnd = t and search_near(t, want, 0)
                    if fnd then nf, dtree, n0, n1, found = f, t, fnd, fnd + ulen(want), true; break end
                end
            end
            if not found then return nil, "text not found in the other version" end
        else
            return nil, "text not found in the other version"
        end
        same, f1 = true, nf
    end

    local x0, e0 = Sync.pos_to_xp(dtree, nf, dst.nfrag, n0, "start")
    if not x0 then return nil, e0 end
    local t1 = dtree
    if f1 ~= nf then
        local e1
        t1, e1 = dst:tree(f1)
        if not t1 then return nil, e1 end
    end
    local x1, e1 = Sync.pos_to_xp(t1, f1, dst.nfrag, n1, "end")
    if not x1 then return nil, e1 end
    out.page, out.pos0, out.pos1 = x0, x0, x1
    return out
end

-- How many of the (up to) first 40 highlights of `items` really hold their text in `book`?
-- Returns matching, checked. Used to tell which rendering a set of XPointers was made in.
function Sync.verify_items(items, book)
    local ok, checked = 0, 0
    local trees = book:trees_fn()
    for i = 1, math.min(#items, 40) do
        local it = items[i]
        if type(it) == "table" and is_xp(it.pos0) and is_xp(it.pos1) and type(it.text) == "string"
            and it.text ~= "" and not it.text_edited then
            checked = checked + 1
            local f0, c0 = Sync.xp_to_pos(it.pos0, trees)
            local f1, c1 = Sync.xp_to_pos(it.pos1, trees)
            if f0 and f1 and f0 == f1 then
                local tree = book:tree(f0)
                if tree and text_matches(it, tree, c0, c1) then ok = ok + 1 end
            end
        end
    end
    return ok, checked
end

-- position key for ordering (fragment, count); nil when unknown
function Sync.sort_key(item, book)
    local xp = item.pos0 or item.page
    if not is_xp(xp) then return nil end
    local f, c = Sync.xp_to_pos(xp, book:trees_fn())
    if not f then return nil end
    return f * 1e9 + c
end

function Sync.sort_items(list, book)
    local keyed = {}
    for i, it in ipairs(list) do
        keyed[#keyed + 1] = { it = it, key = Sync.sort_key(it, book) or (1e18 + i), i = i }
    end
    table.sort(keyed, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.i < b.i
    end)
    for i, k in ipairs(keyed) do list[i] = k.it end
end

--------------------------------------------------------------------------
-- Reconciling two lists
--------------------------------------------------------------------------

-- identity of an annotation: its creation time (KOReader's own key); duplicates get a suffix
function Sync.ids(list)
    local ids, seen = {}, {}
    for i, it in ipairs(list) do
        local base = tostring(it.datetime or ("?" .. i))
        local n = (seen[base] or 0) + 1
        seen[base] = n
        ids[i] = n == 1 and base or (base .. "~" .. n)
    end
    return ids
end

-- what counts as "the content changed" (the position differs per rendering, so it is not part of it)
function Sync.fingerprint(it)
    return table.concat({ tostring(it.datetime_updated or ""), tostring(it.note or ""), tostring(it.text or ""),
        tostring(it.color or ""), tostring(it.drawer or ""), tostring(it.text_edited or "") }, "\31")
end

local META_KEYS = { "datetime_updated", "note", "color", "drawer", "note_format" }

local function same_text(x, y)
    return tostring(x.text or "") == tostring(y.text or "") and (x.text_edited or false) == (y.text_edited or false)
end

local function newer(a, b) -- true when a was changed after b
    local x, y = tostring(a.datetime_updated or a.datetime or ""), tostring(b.datetime_updated or b.datetime or "")
    return x > y
end

local function index_by_id(list)
    local ids, map = Sync.ids(list), {}
    for i, it in ipairs(list) do map[ids[i]] = { item = it, index = i } end
    return map, ids
end

--[[
Reconcile `a` and `b` (lists of annotation items; each is changed in place).
 opts.base        { id -> fingerprint } of the last sync, nil on the first one (no deletions then)
 opts.a_to_b(it)  converts an item of a for b  -> item | nil, reason
 opts.b_to_a(it)  converts an item of b for a
 opts.one_way     "a": only a's changes go to b (b is never imported into a, a is the open book)
 opts.skip        { id -> true }: items the user chose not to sync
Returns { added_a, added_b, updated_a, updated_b, deleted_a, deleted_b, failed = { {id, side, item, reason} },
          base = new snapshot }
]]
function Sync.reconcile(a, b, opts)
    local base = opts.base
    local first = base == nil
    base = base or {}
    local amap = index_by_id(a)
    local bmap = index_by_id(b)
    local res = { added_a = 0, added_b = 0, updated_a = 0, updated_b = 0, deleted_a = 0, deleted_b = 0, failed = {} }
    local new_base = {}
    local remove_a, remove_b = {}, {}
    local add_to_a, add_to_b = {}, {}

    local all = {}
    for id in pairs(amap) do all[id] = true end
    for id in pairs(bmap) do all[id] = true end
    local order = {}
    for id in pairs(all) do
        if not (opts.skip and opts.skip[id]) then order[#order + 1] = id end
    end
    table.sort(order)

    for _i, id in ipairs(order) do
        local ea, eb = amap[id], bmap[id]
        if ea and eb then
            local fa, fb = Sync.fingerprint(ea.item), Sync.fingerprint(eb.item)
            if fa ~= fb then
                -- changed on one side or both: the side that changed since the last sync wins;
                -- when both did (or there is no snapshot) the newer one
                local from_a
                local base_fp = base[id]
                if base_fp and base_fp == fb and fa ~= base_fp then from_a = true
                elseif base_fp and base_fp == fa and fb ~= base_fp then from_a = false
                else from_a = newer(ea.item, eb.item) end
                if not from_a and opts.one_way == "a" then
                    new_base[id] = base[id] -- b changed while a is the open book: next full sync
                else
                    local src, dst, dst_list, dst_entry, conv, side
                    if from_a then
                        src, dst, dst_list, dst_entry, conv, side = ea, eb, b, eb, opts.a_to_b, "a"
                    else
                        src, dst, dst_list, dst_entry, conv, side = eb, ea, a, ea, opts.b_to_a, "b"
                    end
                    local item_s, item_d = src.item, dst.item
                    if same_text(item_s, item_d) then
                        for _k, key in ipairs(META_KEYS) do item_d[key] = item_s[key] end
                        new_base[id] = Sync.fingerprint(item_d)
                        if from_a then res.updated_b = res.updated_b + 1 else res.updated_a = res.updated_a + 1 end
                    else
                        -- the highlighted range itself changed: carry the new position over
                        local c, reason = conv(item_s)
                        if c then
                            dst_list[dst_entry.index] = c
                            new_base[id] = Sync.fingerprint(c)
                            if from_a then res.updated_b = res.updated_b + 1 else res.updated_a = res.updated_a + 1 end
                        else
                            new_base[id] = base[id]
                            res.failed[#res.failed + 1] = { id = id, side = side, item = item_s, reason = reason }
                        end
                    end
                end
            else
                new_base[id] = fa
            end
        elseif ea then -- only in a
            if base[id] ~= nil and not first then
                -- it was synced before and b no longer has it: deleted there
                if opts.one_way == "a" then
                    -- b side deletions cannot happen while a is the open book; keep it
                    new_base[id] = base[id]
                else
                    remove_a[#remove_a + 1] = ea.index
                    res.deleted_a = res.deleted_a + 1
                end
            else
                add_to_b[#add_to_b + 1] = { id = id, item = ea.item }
            end
        else -- only in b
            if base[id] ~= nil and not first then
                remove_b[#remove_b + 1] = eb.index
                res.deleted_b = res.deleted_b + 1
            elseif opts.one_way == "a" then
                -- a new item that exists only in b while a is open: leave it for the next full sync
            else
                add_to_a[#add_to_a + 1] = { id = id, item = eb.item }
            end
        end
    end

    local function drop(list, indexes)
        table.sort(indexes, function(x, y) return x > y end)
        for _i, idx in ipairs(indexes) do table.remove(list, idx) end
    end
    drop(a, remove_a)
    drop(b, remove_b)

    for _i, e in ipairs(add_to_b) do
        local conv, reason = opts.a_to_b(e.item)
        if conv then
            b[#b + 1] = conv
            res.added_b = res.added_b + 1
            new_base[e.id] = Sync.fingerprint(conv)
        else
            res.failed[#res.failed + 1] = { id = e.id, side = "a", item = e.item, reason = reason }
        end
    end
    for _i, e in ipairs(add_to_a) do
        local conv, reason = opts.b_to_a(e.item)
        if conv then
            a[#a + 1] = conv
            res.added_a = res.added_a + 1
            new_base[e.id] = Sync.fingerprint(conv)
        else
            res.failed[#res.failed + 1] = { id = e.id, side = "b", item = e.item, reason = reason }
        end
    end
    res.base = new_base
    return res
end

Sync.Book = Book
return Sync
