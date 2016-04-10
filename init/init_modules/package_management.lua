--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.package.management
-- Note        : 
-- 
-- Parametric tools for environment based package loading and importing.
-- 
--------------------------------------------------------------------------------


return function(importer_metadata)
	local GetNextEnvironmentThreshold = GetNextEnvironmentThreshold
	local GetEnvironmentLayer = GetEnvironmentLayer
	local GetOuterEnvironment = GetOuterEnvironment

	local InjectNonPrivatesIntoTable = InjectNonPrivatesIntoTable


	local function GetDebugInfo()
		local i = GetNextEnvironmentThreshold()
		if i then
			return debug.getinfo(i, 'Sl')
		end
	end

	local function push_importer_error(importer, what)
		if type(what) == "string" then
			what = "'" .. what .. "'"
		else
			what = tostring(what or "")
		end
		return error(  ("The %s(%s) call didn't return a table"):format( importer_metadata[importer].name, what), 3  )
	end
	
	
	
	local advanced_prototypes = {}

	local function normalize_args(env, what)
		if type(env) == "table" and env._PACKAGE then
			return env, what
		else
			return GetOuterEnvironment(), env
		end
	end
	
	function advanced_prototypes.Inject(importer)
		assert( type(importer) == "function" )
		assert( type(importer_metadata[importer].name) == "string" )
	
		return function(env, what)
			env, what = normalize_args(env, what)

			local M = importer(what)
			if type(M) ~= "table" then
				push_importer_error(importer, what)
			end

			InjectNonPrivatesIntoTable( env, pairs(M) )
		end
	end
	
	function advanced_prototypes.Bind(importer, attacher, no_metadata)
		assert( type(importer) == "function" )
		if not no_metadata then
			assert( type(importer_metadata[importer].name) == "string" )
		end

		attacher = attacher or AttachMetaIndex
	
		return function(env, what)
			env, what = normalize_args(env, what)

			local M = importer(what)
			if type(M) ~= "table" then
				if no_metadata then
					return error("Call didn't return a table.")
				else
					push_importer_error(importer, what)
				end
			end
	
			attacher( env, M )
	
			return M
		end
	end
	
	function advanced_prototypes.Become(importer)
		assert( type(importer) == "function" )
		assert( type(importer_metadata[importer].name) == "string" )
	
		return function(what)
			local M = importer(what)
			if type(M) ~= "table" then
				push_importer_error(importer, what)
			end
			local env, i = GetOuterEnvironment()
			assert( type(i) == "number" )
			assert( i >= 2 )
			local status, err = pcall(setfenv, i + 1, M)
			if not status then
				return error(err, 2)
			end
			return M
		end
	end


	_M.BindGlobal = (function()
		local assert = assert
		local _G = _G
		local rawget = rawget
		local getmetatable = getmetatable

		local AttachMetaIndexTo = AttachMetaIndexTo

		local function global_get(_, k)
			return rawget(_G, k)
		end

		return function()
			local outer_env = GetOuterEnvironment()
			assert( getmetatable(outer_env) )
			AttachMetaIndexTo(outer_env, global_get, true)
		end
	end)()

	for action, prototype in pairs(advanced_prototypes) do
		for importer, info in pairs(importer_metadata) do
			_M[action .. info.category] = prototype(importer)
		end
	end
