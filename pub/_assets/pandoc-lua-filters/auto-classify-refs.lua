--[[
auto-classify-refs – add .ref-list class to reference headings by auto-id

Matches headings whose Pandoc auto-id is one of the common reference
section identifiers (literatur, literaturverzeichnis, bibliography,
references).  If the heading already carries a ref-list–related class,
the explicit class wins and nothing is changed.

Replaces headings-refs-to-meta.lua, which extracted content into
meta.biblio.  Classification now stays on the heading so that
classes-to-attr can produce sec-type="ref-list" and cleanup.xsl can
move the section to <back>.
]]

local refs_ids = {
  literatur = true,
  literaturverzeichnis = true,
  bibliography = true,
  references = true,
}

local ref_classes = {
  ['ref-list'] = true,
  ['ref-list-wrapper'] = true,
  ['ref-list-shorthands'] = true,
}

function Header(el)
  if not refs_ids[el.identifier] then return nil end
  for _, c in ipairs(el.classes) do
    if ref_classes[c] then return nil end
  end
  el.classes:insert('ref-list')
  return el
end