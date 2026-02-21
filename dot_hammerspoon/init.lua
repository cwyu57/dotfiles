local spaces = require("hs.spaces")

local BUNDLE_ID = 'org.alacritty'
local TERMINAL_PANEL_HEIGHT = 500

-- Panel frame before going full; restore to this when toggling back (so user's resize is kept)
local currentTerminalPanelFrame = nil
local savedTerminalPanelFrameOnLeavingFull = nil

-- Switch alacritty (show/hide, dock from bottom)
hs.hotkey.bind({'command'}, 'escape', function ()
  function moveWindow(alacritty, space, mainScreen)
    -- move to current space, panel from bottom above macOS Dock
    local win = nil

    local attempts = 0
    while win == nil and attempts < 10 do
      win = alacritty:mainWindow()
      hs.timer.usleep(100000) -- 0.1s
      attempts = attempts + 1
    end

    if win == nil then
      print('Failed to find alacritty window')
      return
    end

    local fullFrame = mainScreen:fullFrame() -- fullFrame = entire screen
    local usableFrame = mainScreen:frame() -- usableFrame = usable area excluding menu bar and Dock

    -- Dock height (bottom): space reserved by macOS Dock below usable area
    local dockHeight = (fullFrame.y + fullFrame.h) - (usableFrame.y + usableFrame.h)

    -- Position panel in usable area so it sits just above the Dock
    local winFrame = win:frame()
    local h = math.min(
      (currentTerminalPanelFrame and currentTerminalPanelFrame.h) or TERMINAL_PANEL_HEIGHT, 
      usableFrame.h
    )
    winFrame.x = usableFrame.x
    winFrame.w = usableFrame.w
    winFrame.h = h
    winFrame.y = usableFrame.y + usableFrame.h - h
    win:setFrame(winFrame, 0)
    currentTerminalPanelFrame = winFrame
    spaces.moveWindowToSpace(win, space)

    win:focus()
  end

  local alacritty = hs.application.get(BUNDLE_ID)

  if alacritty ~= nil and alacritty:isFrontmost() then
    alacritty:hide()
  else
    local space = spaces.activeSpaceOnScreen()
    local mainScreen = hs.screen.mainScreen()

    if alacritty == nil and hs.application.launchOrFocusByBundleID(BUNDLE_ID) then
      local appWatcher = nil
      appWatcher = hs.application.watcher.new(function(name, event, app)
        if event == hs.application.watcher.launched and app:bundleID() == BUNDLE_ID then
          app:hide()
          moveWindow(app, space, mainScreen)
          appWatcher:stop()
        end
      end)
      appWatcher:start()
    end

    if alacritty ~= nil then
      moveWindow(alacritty, space, mainScreen)
    end
  end
end)

-- Toggle full (usable area) <-> panel size (Cmd+Option+M); restore to last panel size if resized
hs.hotkey.bind({'command', }, 'return', function ()
  local alacritty = hs.application.get(BUNDLE_ID)
  if alacritty == nil then return end

  local win = alacritty:mainWindow()

  local screen = win:screen() or hs.screen.mainScreen()
  local usableFrame = screen:frame()
  local currentFrame = win:frame()

  -- If height is nearly full usable height, treat as full -> restore to saved panel size
  if currentFrame.h >= usableFrame.h - 2 then
    win:setFrame(savedTerminalPanelFrameOnLeavingFull, 0)
    currentTerminalPanelFrame = savedTerminalPanelFrameOnLeavingFull

  else
    -- Save current frame (copy) before going full so we can restore user's size
    savedTerminalPanelFrameOnLeavingFull = hs.geometry.rect(currentFrame.x, currentFrame.y, currentFrame.w, currentFrame.h)
    win:setFrame(usableFrame, 0)
    currentTerminalPanelFrame = usableFrame
  end
end)

-- Switch to ABC layout when alacritty is activated to fix cmd+c/v in alacritty
hs.application.watcher.new(function(appName, event, app)
  if event == hs.application.watcher.activated then
    if app:bundleID() == BUNDLE_ID then
      hs.keycodes.setLayout("ABC")
    end
  end
end):start()