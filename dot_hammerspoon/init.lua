local spaces = require("hs.spaces")

local BUNDLE_ID = 'com.mitchellh.ghostty'
local TERMINAL_PANEL_HEIGHT = 500

-- Where the panel last sat; its height carries over to the next show
local currentTerminalPanelFrame = nil
-- Panel frame before going full, so toggling back keeps a manual resize
local savedTerminalPanelFrameOnLeavingFull = nil
-- Toggle state, not inferred from the height: a full window rarely lands on exactly usableFrame.h
local isFull = false
-- Window we last docked; its live height already includes any manual resize
local positionedWindowId = nil

-- Ghostty stays alive with no windows, and a new one takes a moment to appear
local function waitForMainWindow(app)
  local attempts = 0
  while attempts < 20 do
    local win = app:mainWindow()
    if win ~= nil then return win end
    hs.timer.usleep(100000) -- 0.1s
    attempts = attempts + 1
  end
  return nil
end

-- Pull the window flush with the bottom: it can settle shorter than the frame we
-- set, and macOS keeps the top-left corner, leaving a gap above the Dock. Moves
-- only, never resizes, so it cannot feed back into the height.
local function anchorToBottom(win, usableFrame)
  hs.timer.doAfter(0.05, function() -- let the resize settle first
    local frame = win:frame()
    local bottom = usableFrame.y + usableFrame.h

    if math.abs((frame.y + frame.h) - bottom) > 0.5 then
      win:setTopLeft({ x = frame.x, y = bottom - frame.h })
    end

    currentTerminalPanelFrame = win:frame()
  end)
end

-- Show as a panel docked to the bottom of the current space, above the macOS Dock
local function showPanel(app, space, mainScreen)
  local win = waitForMainWindow(app)

  if win == nil then
    print('Failed to find Ghostty window')
    return
  end

  local usableFrame = mainScreen:frame() -- excludes menu bar and Dock

  -- The same window keeps the height it has now; a new one falls back to the
  -- last panel height, then to the default
  local winFrame = win:frame()
  local h = math.min(
    (positionedWindowId == win:id() and winFrame.h)
      or (currentTerminalPanelFrame and currentTerminalPanelFrame.h)
      or TERMINAL_PANEL_HEIGHT,
    usableFrame.h
  )
  winFrame.x = usableFrame.x
  winFrame.w = usableFrame.w
  winFrame.h = h
  winFrame.y = usableFrame.y + usableFrame.h - h
  win:setFrame(winFrame, 0)
  currentTerminalPanelFrame = winFrame
  positionedWindowId = win:id()
  spaces.moveWindowToSpace(win, space)

  win:focus()
  anchorToBottom(win, usableFrame)
end

-- Switch Ghostty (show/hide, dock from bottom)
hs.hotkey.bind({'command'}, 'escape', function ()
  local app = hs.application.get(BUNDLE_ID)

  if app ~= nil and app:isFrontmost() then
    app:hide()
    return
  end

  local space = spaces.activeSpaceOnScreen()
  local mainScreen = hs.screen.mainScreen()

  if app == nil then
    if hs.application.launchOrFocusByBundleID(BUNDLE_ID) then
      local appWatcher = nil
      appWatcher = hs.application.watcher.new(function(name, event, launchedApp)
        if event == hs.application.watcher.launched and launchedApp:bundleID() == BUNDLE_ID then
          launchedApp:hide()
          showPanel(launchedApp, space, mainScreen)
          appWatcher:stop()
        end
      end)
      appWatcher:start()
    end
    return
  end

  -- Running, but possibly with no window at all: a reopen makes Ghostty create one
  if app:mainWindow() == nil then
    hs.application.launchOrFocusByBundleID(BUNDLE_ID)
  end

  showPanel(app, space, mainScreen)
end)

-- Toggle full height <-> panel height (Cmd+Return)
hs.hotkey.bind({'command', }, 'return', function ()
  local app = hs.application.get(BUNDLE_ID)
  if app == nil then return end

  local win = app:mainWindow()
  if win == nil then return end

  local screen = win:screen() or hs.screen.mainScreen()
  local usableFrame = screen:frame()
  local currentFrame = win:frame()

  if isFull then
    local restoreFrame = savedTerminalPanelFrameOnLeavingFull
    if restoreFrame == nil then
      -- Started out full, so there is no panel size to go back to
      local h = math.min(TERMINAL_PANEL_HEIGHT, usableFrame.h)
      restoreFrame = hs.geometry.rect(
        usableFrame.x,
        usableFrame.y + usableFrame.h - h,
        usableFrame.w,
        h
      )
    end
    win:setFrame(restoreFrame, 0)
    currentTerminalPanelFrame = restoreFrame
    isFull = false

  else
    -- Copy the frame before going full so the user's size comes back
    savedTerminalPanelFrameOnLeavingFull = hs.geometry.rect(currentFrame.x, currentFrame.y, currentFrame.w, currentFrame.h)
    win:setFrame(usableFrame, 0)
    currentTerminalPanelFrame = usableFrame
    isFull = true
  end

  anchorToBottom(win, usableFrame)
end)
