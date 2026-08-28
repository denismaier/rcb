-- wraps lines in lineblocks in a span "verse-line"
-- for divs with class "verse" or "verse-centered"
-- additionally: adds an attribute "content-type" with the value of the class


local function wrap_line_in_span (elem, name)
  local span = pandoc.Span(elem, { class = name })
  return pandoc.List{ span }
end

function Div(el)
  if el.classes:includes('verse') or el.classes:includes('verse-centered') then
    el.attr = {["content-type"] = el.classes[1]}
	return el:walk {
		LineBlock = function(el)
			local lines = {}
			for i, line in ipairs(el.content) do
				lines[i] = wrap_line_in_span(line, 'verse-line')
			end
			el.content = pandoc.List(lines)
			return el
		end
      }
    end
end
