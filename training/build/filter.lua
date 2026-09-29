-- Adapts the training Markdown for the published site.

local GITHUB = {
  ["release"] = "https://github.com/kubernetes/release",
  ["sig-release"] = "https://github.com/kubernetes/sig-release",
}

local function escape_html(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Link(el)
  local t = el.target

  -- Workspace-relative links to upstream repos become GitHub links.
  local repo, rest = t:match("^%.%./%.%./%.%./([%w%-]+)/?(.*)$")
  if repo and GITHUB[repo] then
    el.target = rest == "" and GITHUB[repo] or GITHUB[repo] .. "/blob/master/" .. rest
    return el
  end

  -- Team-internal files (log.md, CHECKLIST.md) aren't published; keep the text only.
  if t:match("^%.%./") then
    return el.content
  end

  el.target = (t:gsub("^([%w%-]+)%.md(#?.*)$", "%1.html%2"))
  return el
end

function CodeBlock(el)
  if el.classes:includes("mermaid") then
    return pandoc.RawBlock("html", '<pre class="mermaid">' .. escape_html(el.text) .. "</pre>")
  end
end

function Table(el)
  return pandoc.Div(el, { class = "scroll" })
end

-- The first H1 becomes the page title in the masthead.
function Pandoc(doc)
  local first = doc.blocks[1]
  if first and first.t == "Header" and first.level == 1 then
    doc.meta.title = first.content
    doc.blocks:remove(1)
  end
  return doc
end
