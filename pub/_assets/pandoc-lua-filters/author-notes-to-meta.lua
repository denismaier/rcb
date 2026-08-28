--[[
notes-to-meta – move an "notes" section into document metadata
]]
local notes = {}

--- Extract notes from a list of blocks.
function notes_from_blocklist (blocks)
  local body_blocks = {}
  local looking_at_notes = false

  for _, block in ipairs(blocks) do
    if block.t == 'Header' and block.level == 1 then
      if block.identifier == 'author-notes' then
        looking_at_notes = true
      else
        looking_at_notes = false
        body_blocks[#body_blocks + 1] = block
      end
    elseif looking_at_notes then
      if block.t == 'HorizontalRule' then
        looking_at_notes = false
      else
        notes[#notes + 1] = block
      end
    else
      body_blocks[#body_blocks + 1] = block
    end
  end

  return body_blocks
end

if PANDOC_VERSION >= {2,9,2} then
  -- Check all block lists with pandoc 2.9.2 or later
  return {{
      Blocks = notes_from_blocklist,
      Meta = function (meta)
        if not meta.notes and #notes > 0 then
          meta.notes = pandoc.MetaBlocks(notes)
        end
        return meta
      end
  }}
else
  -- otherwise, just check the top-level block-list
  return {{
      Pandoc = function (doc)
        local meta = doc.meta
        local other_blocks = notes_from_blocklist(doc.blocks)
        if not meta.notes and #notes > 0 then
          meta.notes = pandoc.MetaBlocks(notes)
        end
        return pandoc.Pandoc(other_blocks, meta)
      end,
  }}
end
