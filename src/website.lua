--- === Website ===
---
--- Website class that subclasses [Entity](Entity.html) to represent some automatable website entity
---
local File = require("file")
local Entity = require("entity")
local Website = Entity:subclass("Website")
local spoonPath = hs.spoons.scriptPath()

--- Website.links
--- Variable
--- An array of website links used in the default [`Website:getChooserItems`](#getChooserItems) method (defaults to an empty list). Any of the following values can be inserted:
---  * A complete URL string, i.e. `"https://translate.google.com"`
---  * A URL path string that can be appended to the website entity's initialized URL, i.e. `"/calendar"`
---  * A table containing a `name` string and `link` field that can be either the complete URL string or URL path, i.e.
---  ```
---  { name = "Google Translate", link = "https://translate.google.com" }
---  ```
Website.links = {}

--- Website.displayChooserIcons
--- Variable
--- A boolean value to specify whether to show favicons in the chooser or not. Defaults to `true`.
Website.displayChooserIcons = true

-- Register default website chooser shortcuts
Website:registerChooserShortcuts({
    -- Open selected url in the background
    { { "cmd" }, "return", function(chooser)
        local choice = chooser:selectedRowContents()
        return Website.open(choice.url)
    end },
    -- Copy the selected url to clipboard
    { { "cmd" }, "c", function(chooser)
        local choice = chooser:selectedRowContents()
        chooser:cancel()
        return hs.pasteboard.setContents(choice.url)
    end },
})

--- Website.behaviors
--- Variable
--- Website [behaviors](Entity.html#behaviors) defined to invoke event handlers with the URL of the website.
--- Currently supported behaviors:
--- * `default` - Simply triggers the event handler with the initialized website url
--- * `select` - Generates a list of choice items from [`Website:getChooserItems`](#getChooserItems) and displays them in a chooser for selection
--- * `website` - Triggers the appropriate event handler for the website. Depending on whether the workflow includes select mode, the select mode behavior will be triggered instead
Website.behaviors = Entity.behaviors + {
    default = function(self, eventHandler)
        eventHandler(self.url)
        return true
    end,
    select = function(self, eventHandler)
        local choices = self:getChooserItems()
        local function updateChoices()
            return choices
        end

        if choices and #choices > 0 then
            local function onSelection(choice)
                if choice then
                    eventHandler(choice.url or self.url, choice)
                end
            end

            self:showChooser(updateChoices, onSelection)
        end

        return true
    end,
    website = function(self, eventHandler, _, _, workflow)
        local shouldSelect = false

        for _, event in pairs(workflow) do
            if event.mode == "select" then
                shouldSelect = true
                break
            end
        end

        if shouldSelect and Website.behaviors.select then
            return Website.behaviors.select(self, eventHandler)
        end

        return self.behaviors.default(self, eventHandler)
    end,
}

--- Website:getDomain(url) -> string or `nil`
--- Method
--- Parses and returns the domain part of the url argument
---
--- Parameters:
---  * `url` - The url string
---
--- Returns:
---   * The string domain of the url or `nil`
function Website.getDomain(url)
    return url:match("[%w%.]*%.(%w+%.%w+)") or url:match("[%w%.]*%/(%w+%.%w+)")
end

--- Website:getFaviconURL(url[, size]) -> string or `nil`
--- Method
--- Returns a URL pointing to a given URL's favicon using Favicon Kit
---
--- Parameters:
---  * `url` - The url string
---  * `size` - The pixel size of the favicon, i.e. `32` for a 32x32 favicon. Defaults to `48`.
---
--- Returns:
---   * The string domain of the url or `nil`
function Website:getFaviconURL(url, size)
    size = size or 48

    local domain = self.getDomain(url)
    if not domain then
        return nil
    end

    return "https://api.faviconkit.com/"..domain.."/"..size
end

--- Website:getChooserItems() -> table of choices or nil
--- Method
--- Generates a list of chooser items using the instance's [`Website.links`](Website.html#links) list. Each item will display the page favicon if the [`Website.displayChooserIcons`](Website.html#displayChooserIcons) option is set to `true`.
---
--- Returns:
---   * A list of choice objects
function Website:getChooserItems()
    local choices = {}

    for _, link in pairs(self.links) do
        local linkStr = link.link or link

        if string.sub(linkStr, 1, 1) == "/" then
            linkStr = self.url..linkStr
        end

        local choice = {}

        if link.name and link.link then
            choice.text = link.name
            choice.subText = linkStr
            choice.url = linkStr
        else
            choice.text = linkStr
            choice.url = linkStr
        end

        if self.displayChooserIcons then
            local favicon = self:getFaviconURL(linkStr)

            if favicon then
                choice.imageURL = favicon
            end
        end

        table.insert(choices, choice)
    end

    self:loadChooserRowImages(choices)

    return choices
end

--- Website:openWith(url)
--- Method
--- Opens a URL with an application selected from a chooser
---
--- Parameters:
---  * `url` - the target url that should be opened with the selected application
---
--- Returns:
---   * None
function Website:openWith(url)
    local allApplicationsPath = spoonPath.."/bin/AllApplications"
    local shellscript = allApplicationsPath.." -path \".empty.webloc\""
    local output = hs.execute(shellscript)
    local choices = File.createFileChoices(string.gmatch(output, "[^\n]+"))

    local function onSelection(choice)
        if not choice then return end

        hs.execute("open -a \""..choice.fileName.."\" "..url)
    end

    -- Defer execution to avoid conflicts with the prior chooser that just closed
    hs.timer.doAfter(0, function()
        self:showChooser(choices, onSelection, {
            placeholderText = "Open with application",
        })
    end)
end

--- Website:open(url)
--- Method
--- Opens the url
---
--- Parameters:
---  * `url` - the address of the url to open
---
--- Returns:
---   * None
function Website.open(url)
    if not url then return nil end

    return hs.urlevent.openURL(url)
end

--- Website:initialize(name, url, links, shortcuts)
--- Method
--- Initializes a new website entity instance with its name, url, links, and custom shortcuts.
---
--- Parameters:
---  * `name` - The name of the website
---  * `url` - The website URL
---  * `links` - Related links to initialize [`Website.links`](#links)
---  * `shortcuts` - The list of shortcuts containing keybindings and actions for the url entity
---
--- Returns:
---  * None
function Website:initialize(options)
    local name, url, links, shortcuts

    if type(options) == "string" then
        name = options
        url = options
    elseif #options > 0 then
        name, url, links = table.unpack(options)
    else
        url = options.url
        name = options.name
        links = options.links
        shortcuts = options.shortcuts
        self.getChooserItems = options.getChooserItems
    end

    self.url = url
    self.links = links

    local mergedShortcuts = self:mergeShortcuts(shortcuts, {
        { nil, nil, self.open, { name, "Open "..name.." in Default Browser" } },
        { { "shift" }, "o", function(...) self:openWith(...) end, { name, "Open "..name.." with Application" } },
        { { "shift" }, "/", function() self.cheatsheet:show(self:getFaviconURL(url, 144)) end, { name, "Show Cheatsheet" } },
    })

    Entity.initialize(self, { name, mergedShortcuts })
end

return Website
