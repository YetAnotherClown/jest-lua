-- ROBLOX upstream: https://github.com/facebook/jest/blob/v28.0.0/packages/test-utils/src/alignedAnsiStyleSerializer.ts
-- /**
--  * Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
--  *
--  * This source code is licensed under the MIT license found in the
--  * LICENSE file in the root directory of this source tree.
--  */

local ansiRegex = require("@pkg/@jsdotlua/pretty-format").plugins.ConvertAnsi.ansiRegex
-- ROBLOX deviation: imported chalk instead of ansi-styles
local chalk = require("@pkg/@jsdotlua/chalk")
-- ROBLOX deviation: omitting prettyFormat import

local function serialize(val: string): string
	-- Return the string itself, not escaped nor enclosed in double quote marks.
	local ansiLookupTable = {
		[chalk.inverse.open] = "<i>",
		[chalk.inverse.close] = "</i>",
		[chalk.bold.open] = "<b>",
		[chalk.dim.open] = "<d>",
		[chalk.green.open] = "<g>",
		[chalk.red.open] = "<r>",
		[chalk.yellow.open] = "<y>",
		[chalk.bgYellow.open] = "<Y>",
		[chalk.bold.close] = "</>",
		[chalk.dim.close] = "</>",
		[chalk.green.close] = "</>",
		[chalk.red.close] = "</>",
		[chalk.yellow.close] = "</>",
		[chalk.bgYellow.close] = "</>",
	}

	return val:gsub(ansiRegex, function(match)
		if ansiLookupTable[match] then
			return ansiLookupTable[match]
		else
			return match
		end
	end)
end

local function test(val: any)
	return typeof(val) == "string"
end

return {
	serialize = serialize,
	test = test,
}
