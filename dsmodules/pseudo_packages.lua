--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.dsmodules.pseudo_packages
-- Note        : 
-- 
-- Defines entries in _G.package.loaded which aid in accessing wicker and mod
-- utilities from the global environment via require.
-- 
--------------------------------------------------------------------------------

local assert = assert
local _K = assert( _K )
local _G = assert( _G )

local package_loaded = assert( _G.package.loaded )

---

local mod_id = assert( GetModId() )

local wickerrequire = assert( wickerrequire )
local modrequire = assert( modrequire )

---

package_loaded[mod_id..".modrequire"] = modrequire
package_loaded[mod_id..".wickerrequire"] = wickerrequire
