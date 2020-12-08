--!nonstrict
-- upstream: https://github.com/facebook/jest/blob/v26.5.3/packages/jest-diff/src/normalizeDiffOptions.ts
-- /**
--  * Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
--  *
--  * This source code is licensed under the MIT license found in the
--  * LICENSE file in the root directory of this source tree.
--  */

local Number = require(script.Parent.Parent.Parent.Packages.LuauPolyfill).Number

-- deviation: omitted chalk import

local NormalizeDiffOptions = {}

function NormalizeDiffOptions.noColor(s): string
	return s
end

local DIFF_CONTEXT_DEFAULT = 5

-- deviation: all color formatting is set to noColor
local OPTIONS_DEFAULT = {
	aAnnotation = 'Expected',
	aColor = NormalizeDiffOptions.noColor,
	aIndicator = '-',
	bAnnotation = 'Received',
	bColor = NormalizeDiffOptions.noColor,
	bIndicator = '+',
	changeColor = NormalizeDiffOptions.noColor,
	changeLineTrailingSpaceColor = NormalizeDiffOptions.noColor,
	commonColor = NormalizeDiffOptions.noColor,
	commonIndicator = ' ',
	commonLineTrailingSpaceColor = NormalizeDiffOptions.noColor,
	contextLines = DIFF_CONTEXT_DEFAULT,
	emptyFirstOrLastLinePlaceholder = '',
	expand = true,
	includeChangeCounts = false,
	omitAnnotationLines = false,
	patchColor = NormalizeDiffOptions.noColor,
}

-- omitting return type due to CLI-37948
-- (E001) Type 'nil | number' could not be converted to 'number'
local function getContextLines(contextLines: number?)
	if typeof(contextLines) == 'number' and
		Number.isSafeInteger(contextLines) and
		contextLines >= 0
	then
		return contextLines
	end
	return DIFF_CONTEXT_DEFAULT
end

-- // Pure function returns options with all properties.
function NormalizeDiffOptions.normalizeDiffOptions(options)
	local ret_options = {}
	for key, value in pairs(OPTIONS_DEFAULT) do
		ret_options[key] = value
	end
	if typeof(options) == 'table' then
		for key, value in pairs(options) do
			ret_options[key] = value
		end
		ret_options['contextLines'] = getContextLines(options.contextLines)
	end
	return ret_options
end

return NormalizeDiffOptions