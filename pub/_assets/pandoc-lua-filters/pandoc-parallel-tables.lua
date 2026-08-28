-- NOTE: this code was generated from MoonScript with moonc.
-- The result is mostly idiomatic Lua.
-- I only added the comments and collapsed some ugly spread-out tables.
-- /bpj

-- This software is Copyright (c) 2021 by Benct Philip Jonsson.
--
-- This is free software, licensed under:
--
--   The MIT (X11) License
--
-- http://www.opensource.org/licenses/mit-license.php

local p = pandoc
-- You may want to hard code the format here!
local tab_pre = p.RawBlock(FORMAT, '<table-wrap content-type="parallel">')
local tab_post = p.RawBlock(FORMAT, '</table-wrap>')
local caption_pre = p.RawBlock(FORMAT, '<caption>')
local caption_post = p.RawBlock(FORMAT, '</caption>')
local Div
Div = function(self)
  if self.classes:includes('maybe-table2lol') then
    if 'parallel' == self.attributes['content-type'] then
      local rv = p.List() -- build return list here
      -- Extract the table and the caption
      local tab, caption
      local filter = {
        Table = function(self, t)
          do
            local c = t.caption
            if c then
              if #c.long > 0 then
                caption = c.long
                -- "Delete" the table caption
                c.long = p.List()
                c.short = p.List()
              end
            end
          end
          tab = t
        end
      }
      -- This is run for its side effects
      -- so we discard the return value
      p.walk_block(self, filter)
      if tab then -- should always be true
        rv[#rv + 1] = tab_pre
        if caption then
          rv[#rv + 1] = caption_pre
          rv.extend(caption)
          rv[#rv + 1] = caption_post
        end
        rv.extend({ tab, tab_post })
      end
      if #rv > 0 then -- should always be true
        return rv
      end
    end
  end
  return nil -- preserve any other div
end
return { { Div = Div } }
