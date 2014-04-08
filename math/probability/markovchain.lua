---
-- @description Implements a discrete Markov Chain over a finite set of states.
-- @author simplex



local Lambda = wickerrequire 'paradigms.functional'
local Pred = wickerrequire 'lib.predicates'
local table = wickerrequire 'utils.table'

---
-- The markov chain class.
--
-- @class table
-- @name MarkovChain
--
local MarkovChain = Class(function(self)
	-- Current state.
	self.state = nil
	
	-- Transition matrix. But instead of numerical indexes, it is indexed
	-- by the states directly, as a hash map of hash maps.
	self.P = {}
end)

Pred.IsMarkovChain = Pred.IsInstanceOf(MarkovChain)


local function _(self)
	if not Pred.IsMarkovChain(self) then
		return error("Markov Chain expected as `self'.", 2)
	end
end


---
-- @class function
--
-- Returns the transition function, which is called on a state change,
-- receiving the old state followed by the new.
--
-- @return the transition function.
function MarkovChain:GetTransitionFn()
	_(self)
	return self.transitionfn or Lambda.Nil
end

---
-- Sets the transition function.
-- 
-- @param fn The new transition function.
function MarkovChain:SetTransitionFn(fn)
	_(self)
	self.transitionfn = fn
end


---
-- @return An iterator triple over the states.
function MarkovChain:States()
	_(self)
	return table.keys(self.P)
end

---
-- @return The current state.
function MarkovChain:GetState()
	_(self)
	return self.state
end
MarkovChain.GetCurrentState = MarkovChain.GetState

---
-- Returns whether the argument is a state.
function MarkovChain:IsState(s)
	_(self)
	return self.P[s] ~= nil
end

---
-- Adds a new state.
function MarkovChain:AddState(s)
	_(self)
	self.P[s] = self.P[s] or {}
end

---
-- Removes a given state.
function MarkovChain:RemoveState(s)
	_(self)
	for _, edges in pairs(Q) do
		edges[s] = nil
	end
	Q[s] = nil
end

---
-- Sets the initial state. If not present already, it is added.
function MarkovChain:SetInitialState(s)
	_(self)
	self:AddState(s)
	self.state = s
end

---
-- Goes to a target state, calling the transition function if the target
-- state differs from the current one.
function MarkovChain:GoTo(t)
	_(self)
	local s = self.state
	if s ~= t then
		assert( self:IsState(t), "Invalid target state." )
		self.state = t
		self:GetTransitionFn()(s, t)
	end
end

---
-- @class function
-- 
-- GoTo alias.
--
-- @see Goto
MarkovChain.GoToState = MarkovChain.GoTo


---
-- Sets the transition probability (for a single step) from u to v.
--
-- @param u The initial state.
-- @param v The target state.
-- @param p The probability of going from u to v.
-- @param symmetric Whether the same probability should be attached to going from v to u.
function MarkovChain:SetTransitionProbability(u, v, p, symmetric)
	_(self)
	assert( self:IsState(u), "Invalid origin state." )
	assert( self:IsState(v), "Invalid target state." )
	assert( u ~= v, "The origin can't be the same as the target." )
	assert( p == nil or Pred.IsNonNegativeNumber(p) or Pred.IsCallable(p), "The transition rate should be nil, non-negative or a function." )
	if p == 0 then p = nil end

	self.P[u][v] = p

	if symmetric then
		self:SetTransitionProbability(v, u, p, false)
	end
end

---
-- Processes a chain specification in table format.
function MarkovChain:ProcessSpecs(specs)
	_(self)

	self:SetInitialState( assert( specs[1], "Initial state not given." ) )
	
	for pair, p in pairs(specs) do
		if pair ~= 1 then
			assert( Pred.IsTable(pair) and #pair == 2, "State pair expected as spec key." )
			local u, v = unpack(pair)
			self:AddState(u)
			self:AddState(v)
			self:SetTransitionProbability(u, v, p)
		end
	end
end


---
-- Steps the markov chain.
function MarkovChain:Step()
	_(self)

	local p = math.random()

	for u, q in pairs(self.P[self:GetState()]) do
		if Pred.IsCallable(q) then q = q() end
		if p < q then
			self:GoTo(u)
			break
		else
			p = p - q
		end
	end
end
MarkovChain.__call = MarkovChain.Step


---
-- Returns a debug string.
function MarkovChain:__tostring()
	local states = Lambda.CompactlyInjectInto({}, table.keys(self.P))
	local states_str = Lambda.CompactlyMapInto(tostring, {}, ipairs(states))
	local max_len = Lambda.MaximumOf(string.len, ipairs(states_str))
	states_str = Lambda.CompactlyMap(function(v)
		return v..(" "):rep(max_len - #v)
	end, ipairs(states_str))
	local pad_str = (" "):rep(max_len)

	local lines = {}

	table.insert(lines, table.concat(
		Lambda.CompactlyInjectInto({pad_str}, ipairs(states_str))
	, " "))

	local fmt_str = "%"..max_len..".3f"
	for i, s in ipairs(states) do
		local leftover = 1 - Lambda.Fold(Lambda.Add, table.values(self.P[s]))

		table.insert(lines, table.concat(
			Lambda.CompactlyMapInto(function(t, j)
				local val
				if i == j then
					val = leftover
				else
					val = self.P[s][t]
				end
				if val then
					return fmt_str:format(val)
				else
					return ("?"):rep(max_len)
				end
			end, {states_str[i]}, ipairs(states))
		, " "))
	end

	return table.concat(lines, "\n")
end


local function GenerateMethodAliases()
	local affix_aliases = {
		State = {"Node"},
		TransitionProbability = {"EdgeWeight"},
	}

	local new_methods = {}

	for k, v in pairs(MarkovChain) do
		if type(k) == "string" and type(v) == "function" and not k:match("^_") then
			for affix, repl_table in pairs(affix_aliases) do
				local prefix, suffix = k:match("^(.*)" .. affix .. "(.*)$")
				if prefix then for _, repl in ipairs(repl_table) do
					local new_name = prefix .. repl .. suffix
					if MarkovChain[new_name] == nil then
						assert( new_methods[new_name] == nil )
						new_methods[new_name] = v
					end
				end end
			end
		end
	end

	for k, v in pairs(new_methods) do
		MarkovChain[k] = v
	end
end

GenerateMethodAliases()
return MarkovChain
