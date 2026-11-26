-- Pandoc filter for the web pages: gives the template (pandoc/page.html) what
-- is not in the page's own front matter, mainly the lists under its text.

local site = "Reading and focus groups"
local stringify = pandoc.utils.stringify

-- "articles/HomoFaber.md" is an article, "sessions/..." a session, README.md the home page.
local dir, name = PANDOC_STATE.input_files[1]:match("^(.-)/?([^/]+)%.md$")
local root = dir == "" and "" or "../" -- links are relative, so the site works from any address

-- "author, date", the grey line under the title of a list item
local function byline(item)
  local author, date = item.author and stringify(item.author), item.date and stringify(item.date)
  return author and date and author .. ", " .. date or author or date
end

-- The pages of a folder as list items (files starting with "_" are not published).
local function pages(folder)
  local list = {}
  for _, file in ipairs(pandoc.system.list_directory(folder)) do
    local page = file:match("^([^_].*)%.md$")
    if page then
      local f = assert(io.open(folder .. "/" .. file))
      local meta = pandoc.read(f:read("a"), "markdown").meta
      f:close()
      list[#list + 1] = {
        name = page, url = root .. folder .. "/" .. page .. ".html", title = meta.title, byline = byline(meta),
        date = stringify(meta.date or ""):gsub("(%d+)%.(%d+)%.(%d+)", "%3%2%1"), -- 18.11.2026 sorts as 20261118
      }
    end
  end
  return list
end

-- Sessions write their links as `- "Title": { author, date, source }`.
local function links(items)
  local list = {}
  for _, item in ipairs(items or {}) do
    for title, info in pairs(item) do
      list[#list + 1] = { title = title, url = info.source, byline = byline(info) }
    end
  end
  return list
end

function Meta(meta)
  meta.site, meta.root = site, root
  meta.pagetitle = meta.title and stringify(meta.title) .. " · " .. site or site

  local articles = pages("articles")
  if dir == "articles" then
    meta.pdf = name .. ".pdf" -- written next to the page by the Makefile
  elseif dir == "sessions" then
    local readings = {}
    for _, wanted in ipairs(meta.articles or {}) do -- sessions list articles by file name
      local found = { title = stringify(wanted) }
      for _, article in ipairs(articles) do
        if article.name == found.title then found = article end
      end
      readings[#readings + 1] = found
    end
    meta.lists = {
      { heading = "Readings", items = readings },
      { heading = "External links", items = links(meta.external) },
      { heading = "Suggestions", items = links(meta.suggestions) },
    }
  else
    local sessions = pages("sessions")
    table.sort(sessions, function(a, b) return a.date > b.date end) -- latest first
    table.sort(articles, function(a, b) return stringify(a.title):lower() < stringify(b.title):lower() end)
    meta.lists = { { heading = "Sessions", items = sessions }, { heading = "All articles", items = articles } }
  end

  for i = #(meta.lists or {}), 1, -1 do -- no heading without a list
    if #meta.lists[i].items == 0 then table.remove(meta.lists, i) end
  end
  return meta
end
