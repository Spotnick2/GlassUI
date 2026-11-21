-- The manifest, the pinned build, and the library's media.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- WowTestKit's: interface 16001, the version token, every listed .lua file
-- exists, every entry (the library's XML line too) is listed once.
Kit.checkToc(TOC)

local toc = io.open(TOC):read("*a")
check(toc:find("## SavedVariables: GlassUIDB", 1, true), "saved variables declared")
check(toc:find("## X-License: MIT", 1, true), "MIT, like its siblings")
-- The AddOn list's header for the family (Blizzard_AddOnList AddonList.lua:456). Never a
-- Group: GlassPanel's plugins already group under GlassPanel, and the list nests one level.
local tocLF = "\n" .. toc:gsub("\r", "")
check(tocLF:find("\n## Category: |cff7fd4ffGlass|r\n", 1, true), "the Glass category header")
check(not tocLF:find("\n## Group:", 1, true), "no Group line")
-- The CurseForge project, and the Wago one: the `wago` job uploads to the project the packaged
-- TOC names, and the Wago app matches an installed addon by it (RELEASING.md §1).
check(tocLF:find("\n## X-Curse-Project-ID: 1745875\n", 1, true), "the CurseForge project ID")
check(tocLF:find("\n## X-Wago-ID: mNwwPlNo\n", 1, true), "the Wago project ID")
check(not tocLF:find("\n## Dependencies:", 1, true) and not tocLF:find("\n## RequiredDeps:", 1, true),
      "no hard dependency: every Glass addon stands alone")
check(io.open("LICENSE"):read("*a"):find("MIT License", 1, true), "LICENSE is MIT")
eq(tocLines()[1], LIBGLASS_XML, "LibGlass-1.0 loads first")
eq(tocFiles()[1], "Compat.lua", "Compat is the first addon file")
eq(tocFiles()[#tocFiles()], "GlassUI.lua", "bootstrap loads last")
-- The packager replaces its tokens in EVERY file: never write one whole in Lua.
for _, f in ipairs(tocFiles()) do
    local src = io.open(f, "rb"):read("*a")
    local token = src:match("@project%-[%w-]+@") or src:match("@file%-[%w-]+@")
    check(not token, f .. " holds no packager token (found " .. tostring(token) .. ")")
end

local GUI = loadAddon()
eq(GUI.MEASURED_ON_BUILD, "1.60.1.71037", "MEASURED_ON_BUILD")

-- Every texture the library names ships with it. No Media of our own.
local root = libGlassRoot()
for size, S in pairs(GUI.Glass.SIZES) do
    for _, key in ipairs({ "mask", "rim", "dark", "shadow" }) do
        local f = root .. "/Media/" .. S[key] .. ".tga"
        check(io.open(f, "rb") ~= nil, size .. " texture exists: " .. f)
    end
end
eq(GUI.Glass.MEDIA, "Interface\\AddOns\\GlassUI\\Libs\\LibGlass-1.0\\Media\\",
   "Glass.MEDIA is the embedded copy's")
check(GUI.Glass ~= LibStub("LibGlass-1.0"), "Glass is our own instance, not the library")
eq(GUI.Glass.STYLE.thinRim, true, "thin rims (Pearl, and the clean fallback)")

-- The dev-build notice: a deployed dev copy on another build says so once at login.
WoW.build, WoW.version = "70400", "dev"
loadAddon()
check(table.concat(WoW.chat, "\n"):find("differs from the one this addon was measured on", 1, true), "dev copy warns")
WoW.build, WoW.version = "70400", "v0.1.0"
loadAddon()
check(not table.concat(WoW.chat, "\n"):find("differs", 1, true), "a release keeps quiet")
WoW.build = "71037"

done("test_toc")
