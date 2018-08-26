local levels = require "levels"
local level = levels[3]

local colors = {
  [1] = {1, 0, 0},
  [2] = {0, 0.616, 0},
  [3] = {0, 0.467, 0.447},
  [4] = {0, 0.471, 0.718},
  [5] = {0.773, 0, 0},
  __index = {1, 0, 0}
}

local screen_width = 900
local screen_height = 600
local fullscreen = false

local grid_width = 100
local grid_height = 100

local player_sprite = love.graphics.newImage("player.png")
local player_width = 60
local player_height = 60
local player_ox = player_sprite:getWidth() / 2
local player_oy = player_sprite:getHeight() / 2
local player_sx = player_width / player_sprite:getWidth()
local player_sy = player_height / player_sprite:getHeight()
local fov = math.rad(66)
local plane_length = 1
local map_view_distance = 1000
local view_distance = 10
local rotation_speed = math.pi * 1.5
local move_speed = 4

local rotation = 0
local posX, posY = 3, 3

local dir_vector_width = 6
local plane_vector_width = 6
local vec_scale = 50

local canvas
local canvas_width = screen_width / 4
local canvas_height = screen_height / 4

local mapView = false
local brightnessSetting = 0

function love.load()
  love.window.setMode(screen_width, screen_height, {fullscreen = fullscreen})
  canvas = love.graphics.newCanvas(screen_width, screen_height)
end

function love.update(dt)
  -- Movement
  local dx, dy = 0, 0
  if love.keyboard.isDown("up") then
    dx = math.cos(rotation) * move_speed * dt
    dy = math.sin(rotation) * move_speed * dt
  end

  if love.keyboard.isDown("down") then
    dx = -math.cos(rotation) * move_speed * dt
    dy = -math.sin(rotation) * move_speed * dt
  end

  -- Rotation
  if love.keyboard.isDown("left") then
    rotation = rotation + rotation_speed * dt
  end

  if love.keyboard.isDown("right") then
    rotation = rotation - rotation_speed * dt
  end

  -- Floor rotation to 360deg
  rotation = rotation % (math.pi*2)
  -- Check level bound collisions and move accordingly
  local nextX = math.floor(posX + dx)
  if level[nextX][math.floor(posY)] == 0 then
    posX = posX + dx
  end
  local nextY = math.floor(posY + dy)
  if level[math.floor(posX)][nextY] == 0 then
    posY = posY + dy
  end
end

function love.draw()
  -- Draw minimap to canvas
  love.graphics.setCanvas(canvas)
  do
    local w, h = screen_width, screen_height
    local px, py = posX*grid_width, posY*grid_height
    love.graphics.push()
    love.graphics.translate(-px + w/2,-py + h/2)
    -- Background
    love.graphics.clear(0.1, 0.1, 0.1)
    -- Draw fov
    love.graphics.setColor(0.969, 0.976, 0.467, 0.8)
    love.graphics.polygon("fill", px, py,
      px + map_view_distance * math.cos(-fov/2 + rotation),
      py + map_view_distance * math.sin(-fov/2 + rotation),
      px + map_view_distance * math.cos(fov/2 + rotation),
      py + map_view_distance * math.sin(fov/2 + rotation))

    -- Draw level
    for r, _ in ipairs(level) do
      for c, _ in ipairs(level[r]) do
        if level[r][c] > 0 then
          drawWall(r, c)
        end
      end
    end
    -- Draw player
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(player_sprite, px, py, rotation + math.pi/2, player_sx, player_sy, player_ox, player_oy)

    love.graphics.pop()
    -- Draw direction vector
    --love.graphics.setColor(0.5, 0, 0.5)
    --drawLine(x, y, x + dirX, y + dirY, rotation, dir_vector_width)
    -- Draw plane vectors
    --love.graphics.setColor(0, 1, 0)
    --drawLine(x + dirX, y + dirY, x + dirX + planeX, y + dirY + planeY, rotation, plane_vector_width)
    --love.graphics.setColor(1, 0, 0)
    --drawLine(x + dirX, y + dirY, x + dirX - planeX, y + dirY - planeY, rotation, plane_vector_width)
  end
  love.graphics.setCanvas()

  love.graphics.setColor(1, 1, 1, 1)
  if mapView then
    -- Draw minimap
    love.graphics.draw(canvas, 0, 0)
    return
  end

  -- Draw first person view
  for x=0, screen_width do
    local cameraX = x / screen_width * 2 - 1
    local rayDirX = math.cos(rotation) + cameraX * math.cos(rotation - math.pi/2) * plane_length
    local rayDirY = math.sin(rotation) + cameraX * math.sin(rotation - math.pi/2) * plane_length

    local px, py = posX, posY

    local mapX, mapY = math.floor(px), math.floor(py)

    local deltaDistX = math.abs(1/rayDirX)
    local deltaDistY = math.abs(1/rayDirY)
    local perpDist

    local sideDistX, sideDistY
    local stepX, stepY
    local side
    local hit = false

    if rayDirX < 0 then
      stepX = -1
      sideDistX = (px - mapX) * deltaDistX
    else
      stepX = 1
      sideDistX = (mapX + 1 - px) * deltaDistX
    end

    if rayDirY < 0 then
      stepY = -1
      sideDistY = (py - mapY) * deltaDistY
    else
      stepY = 1
      sideDistY = (mapY + 1 - py) * deltaDistY
    end

    while not hit do
      -- Keep jumping to next blocks
      if sideDistX < sideDistY then
        mapX = mapX + stepX
        sideDistX = sideDistX + deltaDistX
        side = 0
      else
        mapY = mapY + stepY
        sideDistY = sideDistY + deltaDistY
        side = 1
      end

      -- Check wall hit
      if level[mapX][mapY] > 0 then
        hit = true
      end
    end

    if side == 0 then
      perpDist = (mapX - px + (1 - stepX) / 2) / rayDirX
    else
      perpDist = (mapY - py + (1 - stepY) / 2) / rayDirY
    end

    local columnHeight = screen_height / perpDist

    local drawStart = screen_height/2 - columnHeight/2
    if drawStart < 0 then drawStart = 0 end
    local drawEnd = screen_height/2 + columnHeight/2
    if drawEnd > screen_height then drawEnd = screen_height - 1 end

    -- Configure color
    local color = colors[level[mapX][mapY]]
    if side == 0 then
      color = {color[1] * 0.9, color[2] * 0.9, color[3] * 0.9}
    end

    -- Draw column
    love.graphics.setColor(color)
    love.graphics.line(x, drawStart, x, drawEnd)
    love.graphics.setColor(1, 1, 1, 1)

    -- Shading --mark sq(perpDist), use 1/perpDist
    if brightnessSetting > 0 then
      local brightness
      if brightnessSetting == 1 then
        brightness = perpDist / view_distance
      elseif brightnessSetting == 2 then
        brightness = sq(perpDist) / view_distance
      else
        brightness = 1/perpDist
      end
      if brightness > 1 then brightness = 1 end
      if brightness < 0 then brightness = 0 end
      love.graphics.setColor(0, 0, 0, brightness)
      love.graphics.line(x, drawStart, x, drawEnd)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Draw minimap
  love.graphics.draw(canvas, screen_width - canvas_width, 0, 0, canvas_width / screen_width,
    canvas_height / screen_height)
  -- Draw brightnessSetting value
  love.graphics.print("Brightness setting "..tostring(brightnessSetting), 10, 10, 0, 1.2, 1.2)
end

function love.keypressed(k)
  if k == "escape" then
    love.event.quit()
  end

  if k == "return" then
    mapView = not mapView
  end

  if k == "b" then
    brightnessSetting = brightnessSetting + 1
    if brightnessSetting > 3 then
      brightnessSetting = 0
    end
  end
end

function drawWall(row, column)
  local x, y = row*grid_width, column*grid_height
  love.graphics.setColor(colors[level[row][column]])
  love.graphics.rectangle("fill", x, y, grid_width, grid_height)
  love.graphics.setColor(1, 1, 1)
end

function drawLine(x1, y1, x2, y2, rot, width)
  for i=-math.floor(width/2), math.floor(width/2) do
    local addX = i * math.sin(-rot)
    local addY = i * math.cos(-rot)
    love.graphics.line(x1 + addX, y1 + addY, x2 + addX, y2 + addY)
  end
end

function sq(x) return x*x end