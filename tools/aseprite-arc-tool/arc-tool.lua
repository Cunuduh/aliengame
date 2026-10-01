-- Arc Tool: draw circular / elliptical arcs through three clicked points,
-- using the active brush, color, and layer.

local dlg = nil
local pending = nil

-- arming an askPoint from inside another askPoint's onclick gets torn down
-- with the click event; re-arm from a one-shot timer instead
local function defer(fn)
  if pending then
    pending:stop()
  end
  pending = Timer{
    interval = 0.05,
    ontick = function()
      pending:stop()
      pending = nil
      fn()
    end,
  }
  pending:start()
end

local function circleFrom3(p1, p2, p3)
  local ax, ay = p1.x, p1.y
  local bx, by = p2.x, p2.y
  local cx, cy = p3.x, p3.y
  local d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
  if math.abs(d) < 1e-9 then
    return nil
  end
  local a2 = ax * ax + ay * ay
  local b2 = bx * bx + by * by
  local c2 = cx * cx + cy * cy
  local ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
  local uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
  local r = math.sqrt((ax - ux) ^ 2 + (ay - uy) ^ 2)
  return ux, uy, r
end

-- start at pStart, end at pEnd, sweeping through pMid
local function circularArcPoints(pStart, pMid, pEnd)
  local ux, uy, r = circleFrom3(pStart, pMid, pEnd)
  if not ux then
    return { pStart, pEnd } -- collinear: straight line
  end
  local a1 = math.atan(pStart.y - uy, pStart.x - ux)
  local am = math.atan(pMid.y - uy, pMid.x - ux)
  local a3 = math.atan(pEnd.y - uy, pEnd.x - ux)
  local tau = 2 * math.pi
  local ccwMid = (am - a1) % tau
  local ccwEnd = (a3 - a1) % tau
  local sweep
  if ccwMid <= ccwEnd then
    sweep = ccwEnd
  else
    sweep = ccwEnd - tau
  end
  local n = math.max(8, math.ceil(math.abs(sweep) * r))
  local pts = {}
  for i = 0, n do
    local a = a1 + sweep * i / n
    pts[#pts + 1] = Point(math.floor(ux + r * math.cos(a) + 0.5),
                          math.floor(uy + r * math.sin(a) + 0.5))
  end
  return pts
end

-- half-ellipse from pStart to pEnd, apex rise taken from pApex's
-- perpendicular distance to the base line
local function ellipseArcPoints(pStart, pEnd, pApex)
  local dx, dy = pEnd.x - pStart.x, pEnd.y - pStart.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1e-9 then
    return { pStart }
  end
  local ux, uy = dx / len, dy / len
  local px, py = -uy, ux
  local mx, my = (pStart.x + pEnd.x) / 2, (pStart.y + pEnd.y) / 2
  local h = (pApex.x - mx) * px + (pApex.y - my) * py
  if math.abs(h) < 0.5 then
    return { pStart, pEnd }
  end
  local a = len / 2
  local n = math.max(8, math.ceil(math.pi * math.max(a, math.abs(h))))
  local pts = {}
  for i = 0, n do
    local t = math.pi * (1 - i / n)
    local ca, sh = a * math.cos(t), h * math.sin(t)
    pts[#pts + 1] = Point(math.floor(mx + ux * ca + px * sh + 0.5),
                          math.floor(my + uy * ca + py * sh + 0.5))
  end
  return pts
end

local function dedupe(pts)
  local out = {}
  for _, p in ipairs(pts) do
    local last = out[#out]
    if not last or last.x ~= p.x or last.y ~= p.y then
      out[#out + 1] = p
    end
  end
  return out
end

local function drawArc(clicks, mode, pixelPerfect)
  local pts
  if mode == "Half-ellipse" then
    pts = ellipseArcPoints(clicks[1], clicks[2], clicks[3])
  else
    pts = circularArcPoints(clicks[1], clicks[3], clicks[2])
  end
  pts = dedupe(pts)
  app.transaction("Arc", function()
    app.useTool{
      tool = "pencil",
      color = app.fgColor,
      brush = app.brush,
      points = pts,
      freehandAlgorithm = pixelPerfect and 1 or 0,
    }
  end)
  app.refresh()
end

local function askArc(mode, pixelPerfect, again)
  if not app.editor then
    app.alert("Open a sprite first.")
    return
  end
  local labels = {
    "Arc: click the START point (1/3)",
    "Arc: click the END point (2/3)",
    mode == "Half-ellipse" and "Arc: click the APEX / rise (3/3)"
                            or "Arc: click a point ON the arc (3/3)",
  }
  local clicks = {}
  local function ask(i)
    app.editor:askPoint{
      title = labels[i],
      onclick = function(ev)
        clicks[i] = ev.point
        if i < 3 then
          defer(function() ask(i + 1) end)
        else
          drawArc(clicks, mode, pixelPerfect)
          if again then
            defer(function() ask(1) end)
          end
        end
      end,
      oncancel = function() end,
    }
  end
  ask(1)
end

local function openDialog()
  if dlg then
    dlg:close()
  end
  dlg = Dialog("Arc Tool")
  dlg:combobox{
    id = "mode",
    label = "Shape",
    option = "Circular",
    options = { "Circular", "Half-ellipse" },
  }
  dlg:check{ id = "pp", text = "Pixel-perfect", selected = true }
  dlg:check{ id = "again", text = "Keep drawing arcs", selected = true }
  dlg:button{
    id = "draw",
    text = "Draw Arc",
    focus = true,
    onclick = function()
      local d = dlg.data
      askArc(d.mode, d.pp, d.again)
    end,
  }
  dlg:button{ id = "close", text = "Close", onclick = function() dlg:close() end }
  dlg:show{ wait = false }
end

function init(plugin)
  plugin:newCommand{
    id = "ArcTool",
    title = "Arc Tool...",
    group = "edit_transform",
    onenabled = function() return app.sprite ~= nil end,
    onclick = openDialog,
  }
end

function exit(plugin)
  if pending then
    pending:stop()
    pending = nil
  end
  if dlg then
    dlg:close()
  end
end
