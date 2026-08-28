--[[
auto-classify-app-figures – add .app-figures class to figure-section headings by auto-id

Matches headings whose Pandoc auto-id is one of the common figure-section
identifiers (abbildungen, bilder, darstellungen, figures, illustrations).
If the heading already carries .app-figures, the explicit class wins.

Mirrors auto-classify-refs.lua. classes-to-attr.lua then produces
sec-type="app-figures", and _back-moves.xsl moves the section (with its
<fig>s) into <back><app-group><app>. Lets the author write "# Abbildungen"
in Word instead of requiring an MD override with {.app-figures}.

JNDF convention (2026-08-25): a heading matching these texts is always the
figure appendix.
]]

local app_fig_ids = {
  abbildungen = true,
  bilder = true,
  darstellungen = true,
  figures = true,
  illustrations = true,
}

function Header(el)
  if not app_fig_ids[el.identifier] then return nil end
  for _, c in ipairs(el.classes) do
    if c == 'app-figures' then return nil end
  end
  el.classes:insert('app-figures')
  return el
end