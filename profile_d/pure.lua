local dflt_boot_params = {
   	id = "USER",

	usercode_root = ".",

	debug = true, 
}

return krequire("profile_d.common")(function(resume_kernel)
    local boot_params = coroutine.yield() or {}
    boot_params = weakMerge(boot_params, dflt_boot_params)
    return assert( coroutine.yield( resume_kernel(boot_params) ) )
end)
