-- ROBLOX upstream: https://github.com/facebook/jest/tree/v28.0.0/packages/jest-util/src/clearLine.ts

--[[*
 * Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 ]]

local LuauPolyfill = require("@pkg/@jsdotlua/luau-polyfill")
local Boolean = LuauPolyfill.Boolean
local RobloxShared = require("@pkg/@jsdotlua/jest-roblox-shared")
type Writeable = RobloxShared.Writeable
local exports = {}

local function clearLine(stream: Writeable): ()
	if Boolean.toJSBoolean(stream.isTTY) then
		stream:write("\x1b[999D\x1b[K")
	end
end
exports.default = clearLine

return exports
