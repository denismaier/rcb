if FORMAT:match 'html' then return {} end

function RawBlock (raw)
  if raw.format == 'html' then
	return pandoc.read(raw.text, 'html').blocks
  end
end
