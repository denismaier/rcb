-- convert classes to attributes for jats

local regular_classes_to_convert = {
	'epigraph',
	'dedication',
	'verse',
	'verse-centered',
	'parallel',
	'parallel-verse',
	'signature',
	'lettersignature',
	'flushleft',
	'preformat',
	'attrib',
	'righttoleft',
	'blockquotenoindenting',
	'fig-group',
	'float',
	'labeled',
	}

local header_classes_to_convert = {
	'floats-group',
	'app-figures',
	'ref-list-wrapper',
	'ref-list-shorthands',
	'ref-list',
	'thought-break',
	'thought-break-asterism',
}

local function classes_to_attributes(el)
  for _, class in ipairs(regular_classes_to_convert) do
    -- print("Checking " .. class)
    if el.classes ~= nil and el.classes:includes(class) then
	  -- print("found")
	  old_content = el.attr['content-type'] or ''
	  if old_content ~= '' then old_content = ' ' .. old_content end
	  el.attr = {['content-type'] = class .. old_content}
	end
  end
  return el
end

local function header_classes_to_attributes(el)
  for _, class in ipairs(header_classes_to_convert) do
    -- print("Checking " .. class)
    if el.classes ~= nil and el.classes:includes(class) then
	  -- print("found")
	  old_content = el.attr['sec-type'] or ''
	  if old_content ~= '' then old_content = ' ' .. old_content end
	  el.attr = {['sec-type'] = class .. old_content}
	end
  end
  return el
end

return {
	{Div = classes_to_attributes},
	{Header = header_classes_to_attributes},
}
