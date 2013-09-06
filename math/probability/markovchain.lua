--[[
Copyright (C) 2013  simplex

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--


--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )

--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'
local Pred = wickerrequire 'lib.predicates'
local table = wickerrequire 'utils.table'


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
		return error("Continuous-Time Markov Chain expected as `self'.", 2)
	end
end


-- Transition function.
-- Called on a state change, receiving the old state followed by the new.
function MarkovChain:GetTransitionFn()
	_(self)
	return self.transitionfn or Lambda.Nil
end

function MarkovChain:SetTransitionFn(fn)
	_(self)
	self.transitionfn = fn
end


-- Returns an iterator triple.
function MarkovChain:States()
	_(self)
	return table.keys(self.P)
end

function MarkovChain:GetState()
	_(self)
	return self.state
end
MarkovChain.GetCurrentState = MarkovChain.GetState

function MarkovChain:IsState(s)
	_(self)
	return self.P[s] ~= nil
end

function MarkovChain:AddState(s)
	_(self)
	self.P[s] = self.P[s] or {}
end

function MarkovChain:RemoveState(s)
	_(self)
	for _, edges in pairs(Q) do
		edges[s] = nil
	end
	Q[s] = nil
end

function MarkovChain:SetInitialState(s)
	_(self)
	self:AddState(s)
	self.state = s
end

function MarkovChain:GoTo(t)
	_(self)
	local s = self.state
	if s ~= t then
		assert( self:IsState(t), "Invalid target state." )
		self:GetTransitionFn()(s, t)
		self.state = t
	end
end
MarkovChain.GoToState = MarkovChain.GoTo


-- Sets the transition probability (for a single step) from u to v.
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
