-- upstream: https://github.com/facebook/jest/blob/v26.5.3/packages/jest-get-type/src/index.ts
-- /**
--  * Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
--  *
--  * This source code is licensed under the MIT license found in the
--  * LICENSE file in the root directory of this source tree.
--  */

local Polyfill = require(script.Parent.Parent.Parent.LuauPolyfill)
local RegExp = Polyfill.RegExp
local instanceof = Polyfill.instanceof

local function getType(value: any): string
	-- deviation: code omitted because lua has no primitive undefined type
	-- lua makes no distinction between null and undefined so we just return nil
	if value == nil then
		return 'nil'
	elseif typeof(value) == 'boolean' then
		return 'boolean'
	elseif typeof(value) == 'function' then
		return 'function'
	elseif typeof(value) == 'number' then
		return 'number'
	elseif typeof(value) == 'string' then
		return 'string'
	elseif typeof(value) == 'DateTime' then
		return 'DateTime'
	elseif typeof(value) == 'userdata' and tostring(value):match("Symbol%(.*%)") then
		return 'symbol'
	elseif instanceof(value, RegExp) then
		return 'regexp'
	-- deviation: lua makes no distinction between tables, arrays, and objects
	-- we always return table here and consumers are expected to perform the check
	elseif typeof(value) == 'table' then
		return 'table'
	-- deviation: code omitted because lua has no primitive bigint type
	-- deviation: code omitted because lua has no built-in Map, or Set types
	-- deviation: code omitted because lua makes no distinction between tables, arrays, and objects
	end

	error(string.format('value of unknown type: %s', tostring(value)))
end

local function isPrimitive(value: any): boolean
	-- deviation: explicitly define objects and functions as non primitives
	return typeof(value) ~= 'table' and typeof(value) ~= 'function'
end

return {
	getType = getType,
	isPrimitive = isPrimitive,
}