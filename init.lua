local function pack(...)
	local n = select('#',...)
	local t = {...}
	return function()
		return unpack(t, 1, n)
	end, t
end

local function splurp_node(name, def)
	local over = {}
	local allow_put = def.allow_metadata_inventory_put
	local allow_move = def.allow_metadata_inventory_move
	or function(pos, from_list, from_index)
		return minetest.get_meta(pos)
			:get_inventory()
			:get_stack(from_list, from_index)
			:get_count()
	end
	local on_put = def.on_metadata_inventory_put or function() end
	local on_construct = def.on_construct or function() end
	local on_timer = def.on_timer or function() end
	if not allow_put then return end
	if not on_timer then return end
	local function construct(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if  inv:get_size("src") == 1
		and inv:get_size("dst") > 0
		and inv:get_size("fuel") == 1
		then
			inv:set_size("cooksneak",1)
			local list = inv:get_list("cooksneak")
			if list[1]:get_count() > 0 then
				minetest.handle_node_drops(pos, list)
				list[1]:set_count(0)
				inv:set_list("cooksneak", list)
			end
			if  meta:get_string("formspec") ~= ""
			and meta:get_string("cooksneak_injection") == ""
			then
				meta:set_string("formspec",meta:get_string("formspec"))
			end
		end
	end
	def.on_construct = function(...)
		local ret = pack(on_construct(...))
		construct(...)
		return ret()
	end
	def.on_timer = function(...)
		local ret = pack(on_timer(...))
		construct(...)
		return ret()
	end
	local function room_in_list(inv, listname, stack)
		local list = inv:get_list(listname)
		local count = stack:get_count() - inv:add_item(listname, stack):get_count()
		inv:set_list(listname, list)
		return count
	end
	local function cooklist(stack)
		if minetest.get_craft_result({method = "cooking", width = 1, items = {stack}}).time ~= 0 then
			return "src"
		elseif minetest.get_craft_result({method = "fuel", width = 1, items = {stack}}).time ~= 0 then
			return "fuel"
		end
		return "src"
	end
	over.allow_metadata_inventory_put = function(pos, listname, index, stack, ...)
		if listname ~= "cooksneak" then
			return allow_put(pos, listname, index, stack, ...)
		end
		local inv = minetest.get_meta(pos):get_inventory()
		local output = cooklist(stack)
		local ret, ret_t = pack(allow_put(pos, output, index, stack, ...))
		ret_t[1] = math.min(ret_t[1], room_in_list(inv, output, stack))
		return ret()
	end
	over.allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, ...)
		if from_list == "cooksneak" or to_list == "cooksneak" then
			return 0
		end
		return allow_move(pos, from_list, from_index, to_list, to_index, ...)
	end
	over.on_metadata_inventory_put = function(pos, listname, index, stack, ...)
		if listname ~= "cooksneak" then
			return on_put(pos, listname, index, stack, ...)
		end
		local inv = minetest.get_meta(pos):get_inventory()
		local output = cooklist(stack)
		inv:add_item(output, inv:remove_item("cooksneak", stack))
		return on_put(pos, output, index, stack, ...)
	end
	minetest.override_item(name, over)
end

for name, def in pairs(minetest.registered_nodes) do
	splurp_node(name, def)
end

local register_node = minetest.register_node
function minetest.register_node(name, def, ...)
	local ret = pack(register_node(name, def, ...))
	splurp_node(def.name, def)
	return ret()
end

minetest.after(0, function()
	local meta = getmetatable(minetest.get_meta(vector.new(0,0,0)))
	local set_string = meta.set_string
	function meta.set_string(self, k, v, ...)
		if k == "formspec" and self:get_inventory():get_list("cooksneak") then
			v = v:gsub(table.concat({
				"listring[context;dst]",
				"listring[current_player;main]",
				"listring[context;src]",
				"listring[current_player;main]",
				"listring[context;fuel]",
				"listring[current_player;main]",
			}):gsub("%p","%%%0"):gsub("context","([%%w_]+)"), table.concat {
				"listring[%1;cooksneak]",
				"listring[current_player;main]",
				"listring[%1;cooksneak]",
				"listring[%1;dst]",
				"listring[current_player;main]",
				"listring[%1;src]",
				"listring[current_player;main]",
				"listring[%1;fuel]",
				"listring[current_player;main]",
				-- -- DEBUG
				-- "list[%1;cooksneak;0,0;1,1;]",
			})
			self:set_string("cooksneak_injection", "1")
		end
		return set_string(self, k, v, ...)
	end
end)
