local assert = assert

local _K = assert( _K )
local _G = assert( _G )

local uuid = assert( uuid )

---

----------

return function()
	local kernel = _M
	local _G = kernel._G

	---
	
	PLATFORM_DETECTION = {}
	INTROSPECTION_LIB = {}

	tee(kernel, PLATFORM_DETECTION)
	tee(kernel, INTROSPECTION_LIB)

	---

	include_corelib(kernel)

	include_platform_detection_functions(kernel)

	include_constants(kernel)
	clear_tee(kernel, PLATFORM_DETECTION)

	include_introspectionlib(kernel)
	clear_tee(kernel, INTROSPECTION_LIB)

	_M.metatable = include_metatablelib(kernel)

	include_auxlib(kernel)

	---

	assert( IsDST )
end
