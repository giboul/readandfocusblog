-- Pandoc filter for the PDFs: the first paragraph of an article opens with a
-- decorated initial, \lettrine{R}{egarding}, and is followed by \lettrinepad
-- (see _includes/article.tex).

-- Quotation marks that may come before the initial: \lettrine[ante=“]{T}{he}.
-- (pandoc reads a paragraph starting with ‘ as starting with ’, hence the last one)
local quotes = { ["\""] = "“", ["'"] = "‘", ["“"] = "“", ["‘"] = "‘", ["«"] = "«", ["’"] = "‘" }

function Pandoc(doc)
  for i, block in ipairs(doc.blocks) do
    local first = block.t == "Para" and block.content[1]
    if first and first.t == "Str" then
      local word, options = first.text, ""
      for quote, opening in pairs(quotes) do
        if word:sub(1, #quote) == quote then
          word, options = word:sub(#quote + 1), "[ante={" .. opening .. "}]"
          break
        end
      end
      local initial, rest = word:match("^(%a)(.*)$") -- unaccented letters only: Romantik has no others
      if initial then
        block.content[1] = pandoc.RawInline("latex", "\\lettrine" .. options .. "{" .. initial:upper() .. "}{")
        block.content:insert(2, pandoc.Str(rest))
        block.content:insert(3, pandoc.RawInline("latex", "}"))
        -- keeps what follows clear of the initial when the paragraph is shorter than it
        doc.blocks:insert(i + 1, pandoc.RawBlock("latex", "\\lettrinepad"))
      end
      return doc
    end
  end
end

-- The link to the source is printed under the date. Pandoc would escape the
-- address as if it were text; \url only needs its % and # escaped.
function Meta(meta)
  if meta.source then
    local address = pandoc.utils.stringify(meta.source):gsub("[%%#]", "\\%0")
    meta.source = pandoc.MetaInlines({ pandoc.RawInline("latex", "\\url{" .. address .. "}") })
    return meta
  end
end
