--[[
image-markers – convert <<IMG: ...>> markers to Pandoc Image elements
Copyright: © 2025 JNDF
License:   MIT

Marker syntax:
<<IMG: filename.ext | caption: Bildunterschrift | float: true | type: figure>>

Parameters:
- filename: required, image file name
- caption: optional, image caption/alt text (no quotes needed)
- float: optional, true/false for floating images
- type: optional, figure/photo/graphic/table (default: figure)
]]

local M = {}

--- Trim whitespace from string
local function trim(s)
  if type(s) ~= "string" then
    return s
  end
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--- Parse image marker text
-- Matches: <<IMG: filename.ext | caption: ... | float: true | type: figure>>
-- Caption takes all text after "caption: " until | or >> (no quotes required)
function M.parse_marker(text)
  local marker = {
    filename = nil,
    caption = "",
    float = false,
    type = "figure"
  }

  -- Extract filename (first parameter after <<IMG:)
  marker.filename = trim(text:match("<<IMG:%s*([^|]+)"))

  -- Extract caption: all text after "caption: " until | or >>
  local caption = text:match('caption:%s*([^|>]+)')
  if caption then
    marker.caption = trim(caption)
  end

  -- Extract float — Lua patterns have no alternation, match any word then compare
  local float = text:match('float:%s*(%w+)')
  if float == "true" or float == "false" then
    marker.float = (float == "true")
  end

  -- Extract type
  local img_type = text:match('type:%s*(%w+)')
  if img_type then
    marker.type = img_type
  end

  return marker
end

--- Check if a paragraph contains an image marker
function M.contains_marker(el)
  local content = pandoc.utils.stringify(el)
  return content:match("<<IMG:") ~= nil
end

--- Convert marker to Pandoc Image element
function M.marker_to_image(marker)
  -- Create caption text
  local caption_text = {}
  if marker.caption and marker.caption ~= "" then
    table.insert(caption_text, pandoc.Str(marker.caption))
  else
    -- Use filename as fallback caption
    table.insert(caption_text, pandoc.Str(marker.filename or ""))
  end

  -- Image reference is the bare filename (pipeline convention: images resolve
  -- flat next to HTML and via ConTeXt imagedir). No path prefix.
  local img_path = marker.filename or "unknown.png"

  -- Create Image element with JATS-compatible attributes
  local img = pandoc.Image(
    caption_text,
    img_path,
    marker.caption or "",
    {
      ["content-type"] = marker.type,
      ["data-float"] = tostring(marker.float)
    }
  )

  return img
end

--- Process Para elements for image markers
function M.Para(el)
  if M.contains_marker(el) then
    local content = pandoc.utils.stringify(el)
    local marker = M.parse_marker(content)

    if marker.filename then
      local img = M.marker_to_image(marker)
      return pandoc.Para({img})
    else
      error("Malformed <<IMG:>> marker (no filename): " .. content)
    end
  end

  return el
end

--- Process Str elements within Para for inline image markers.
--- Pandoc tokenizes text on spaces, so a marker like
--- "<<IMG: foo.jpg | caption: bar>>" becomes several Str/Space inlines.
--- The Str handler therefore only acts on a COMPLETE marker contained in
--- a single Str (has both <<IMG: and >>); fragments are left for the
--- Para handler, which reassembles the whole paragraph via stringify.
function M.Str(el)
  local text = el.text
  if text:match("<<IMG:") and text:match(">>") then
    local marker = M.parse_marker(text)
    if marker.filename then
      return M.marker_to_image(marker)
    else
      error("Malformed <<IMG:>> marker (no filename): " .. text)
    end
  end
  return el
end

if PANDOC_VERSION >= {2,9,2} then
  return {{
    Para = M.Para,
    Str = M.Str
  }}
else
  return {{
    Para = M.Para,
    Str = M.Str
  }}
end
