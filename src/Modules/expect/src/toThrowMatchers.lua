-- upstream: https://github.com/facebook/jest/blob/v26.5.3/packages/expect/src/toThrowMatchers.ts
-- /**
--  * Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
--  *
--  * This source code is licensed under the MIT license found in the
--  * LICENSE file in the root directory of this source tree.
--  *
--  */

local Workspace = script.Parent
local Modules = Workspace.Parent
local Packages = Modules.Parent.Parent

local getType = require(Modules.JestGetType).getType

local Polyfill = require(Packages.LuauPolyfill)
local instanceof = Polyfill.instanceof
local RegExp = Polyfill.RegExp
local Error = Polyfill.Error

local JestMessageUtil = require(Modules.JestMessageUtil)
local formatStackTrace = JestMessageUtil.formatStackTrace
local separateMessageFromStack = JestMessageUtil.separateMessageFromStack

local JestMatcherUtils = require(Modules.JestMatcherUtils)
local EXPECTED_COLOR = JestMatcherUtils.EXPECTED_COLOR
local RECEIVED_COLOR = JestMatcherUtils.RECEIVED_COLOR
local matcherErrorMessage = JestMatcherUtils.matcherErrorMessage
local matcherHint = JestMatcherUtils.matcherHint
local printDiffOrStringify = JestMatcherUtils.printDiffOrStringify
local printExpected = JestMatcherUtils.printExpected
local printReceived = JestMatcherUtils.printReceived
local printWithType = JestMatcherUtils.printWithType
local stringify = JestMatcherUtils.stringify

local Print = require(Workspace.print)
local printExpectedConstructorName = Print.printExpectedConstructorName
local printExpectedConstructorNameNot = Print.printExpectedConstructorNameNot
local printReceivedConstructorName = Print.printReceivedConstructorName
local printReceivedConstructorNameNot = Print.printReceivedConstructorNameNot
local printReceivedStringContainExpectedResult = Print.printReceivedStringContainExpectedResult
local printReceivedStringContainExpectedSubstring = Print.printReceivedStringContainExpectedSubstring

-- deviation: omitted type imports from types file and defined MatcherState as any for now
type MatcherState = any;

local isError = require(Workspace.utils).isError

local DID_NOT_THROW = "Received function never threw"

type Thrown = {
	hasMessage: boolean,
	isError: boolean,
	message: string,
	value: any
};

local toThrowExpectedRegExp, toThrowExpectedAsymmetric, toThrowExpectedObject, toThrowExpectedClass
local toThrowExpectedString, toThrow, formatExpected, formatReceived, formatStack

local function getThrown(e: any): Thrown
	local hasMessage = e ~= nil and typeof(e.message) == "string"

	if hasMessage and typeof(e.name) == "string" and typeof(e.stack) == "string" then
		return {
			hasMessage = hasMessage,
			isError = true,
			message = e.message,
			value = e
		}
	end

	-- We include the following cases for completeness but based on our
	-- deviation of always printing the stack trace even for non-errors
	-- we should always be in the case above
	if hasMessage then
		return {
			hasMessage = hasMessage,
			isError = false,
			message = e.message,
			value = e
		}
	else
		return {
			hasMessage = hasMessage,
			isError = false,
			message = tostring(e),
			value = e
		}
	end
end

local function createMatcher(
	matcherName: string,
	fromPromise: boolean?
)
	return function(
		this: MatcherState,
		received,
		expected: any
	)
		local options = {
			isNot = this.isNot,
			promise = this.promise
		}

		local thrown = nil

		if fromPromise and isError(received) then
			thrown = getThrown(received)
		else
			if typeof(received) ~= "function" then
				if not fromPromise then
					local placeholder

					if expected  == nil then
						placeholder = ""
					else
						placeholder = "expected"
					end

					error(
						matcherErrorMessage(
							matcherHint(matcherName, nil, placeholder, options),
							RECEIVED_COLOR("received") .. " value must be a function",
							printWithType("Received", received, printReceived)
						)
					)
				end
			else
				--[[[
					deviation: error handling in Lua requires us to set the
					stack manually as opposed to relying on the Error object
					to automatically set it.

					deviation: we print the stack for more cases than just
					throwing an Error object since a typical use case in Lua
					would be error("string") and it would be useful to have
					stack trace information for such a case
				]]

				local function getTopStackEntry(stack)
					return string.match(stack, "[^\n]+")
				end
				-- Function used to compare stack traces and cut out unnecessary
				-- information of function calls that are internal to the testing
				-- framework
				local function diffStack(compareStack, currentStack)
					local relevantStack = ""
					local lastRelevantStack = ""
					topCompareStackLine = getTopStackEntry(compareStack)
					for line in string.gmatch(currentStack, "[^\n]+") do
						if line == topCompareStackLine then
							-- we need to exclude the last thing in Stack since
							-- we have a call for the received() function in the
							-- xpcall above so we return lastRelevantStack
							return lastRelevantStack
						end
						lastRelevantStack = relevantStack
						relevantStack = relevantStack .. "\n" .. line
					end
				end

				local compareStack
				local ok, e = xpcall(function()
					compareStack = debug.traceback(nil, 2)
					received()
				end, function(error_)
					local currentStack = debug.traceback()
					local stack = diffStack(compareStack, currentStack)

					if error_ == nil then
						error_ = "nil"
					-- if they specify a table with a message field we treat
					-- that as something they wanted to use to compare their error
					-- message against
					elseif instanceof(error_, Error) or (typeof(error_) == "table" and error_.message) then
						-- Set the stack if it has not been given a value by the user
						if error_.stack == nil then
					 		error_.stack = diffStack(compareStack, debug.traceback())
					 	else
					 		if not error_.stack:find("ThrowMatchers%-test%.js") then
				 				error_.stack = diffStack(compareStack, error_.stack)
					 		end
					 	end
					 	return error_
					elseif typeof(error_) == "string" then
						-- This regex strips out the first part of the error message which typically
						-- looks like LoadedCode....:line_number
						-- The reason we do this is because that information is already reported
						-- as part of the stack trace for a failing error

						-- Important note:
						--[[
							If we had code where we do

								error("Error1")

							but this error is later handled in a typical lua way of using a pcall
							that sets ok, err such as

								if not ok then
									error(string.format('Error2: %s', err))
								end

							then we would have a resulting error message that is something like

								LoadedCode...:line_number1: Error2: LoadedCode...:line_number2: Error1

							in this case, the purpose of the regex is simply to strip out the outermost
							LoadedCode...:line_number string and leave

								Error2: LoadedCode...:line_number2: Error1

							The reason we leave this in is because that LoadedCode...line_number2 string
							is not reported as part of the stack trace anywhere since it was captured and
							re-errored
						]]
						local errorRegex = RegExp("(?:[^\\s]*\\.)+[^\\s]*:[0-9]+:\\s([\\d\\D]*)")
						local result = errorRegex:exec(error_)
						if result[2] ~= nil then
							error_ = result[2]
						end
					elseif typeof(error_) == "table" then
						error_ = stringify(error_)
					end

					local errorObject = Error(error_)
					start, end_ = string.find(errorObject.stack, getTopStackEntry(errorObject.stack), 1, true)
					errorObject.stack = string.sub(errorObject.stack, end_ + 1 + string.len('\n'))
					errorObject.stack = diffStack(compareStack, errorObject.stack)
					errorObject["$$robloxInternalJestError"] = true

					return errorObject
				end)

				if not ok then
					thrown = getThrown(e)
				end
			end
		end

		if expected == nil then
			return toThrow(matcherName, options, thrown)
		elseif typeof(expected) == "table" and typeof(expected.asymmetricMatch) == "function" then
			return toThrowExpectedAsymmetric(matcherName, options, thrown, expected)
		elseif typeof(expected) == "string" then
			return toThrowExpectedString(matcherName, options, thrown, expected)
		elseif instanceof(expected, RegExp) then
			return toThrowExpectedRegExp(matcherName, options, thrown, expected)
		-- deviation: we have different logic for determining if expected is an Error class
		elseif typeof(expected) == "table" and not expected.message then
			return toThrowExpectedClass(matcherName, options, thrown, expected)
		elseif typeof(expected) == "table" then
			return toThrowExpectedObject(matcherName, options, thrown, expected)
		else
			error(
				matcherErrorMessage(
					matcherHint(matcherName, nil, nil, options),
					EXPECTED_COLOR("expected") .. " value must be a string or regular expression or class or error",
					printWithType("Expected", expected, printExpected)
				)
			)
		end
	end
end

local matchers = {
	toThrow = createMatcher("toThrow"),
	toThrowError = createMatcher("toThrowError")
}


--[[
	deviation: In all of the following toThrow functions,
	we have checks to see if we captured an internal error.
	We need to do this because we are returning an error/table
	every time from our error handler but we don't always want to treat the
	result as having thrown an Error. i.e. we don't want to treat error('simple')
	as error(Error('simple'))
]]

-- deviation: expected does not have RegExp type annotation
function toThrowExpectedRegExp(
	matcherName: string,
	options: JestMatcherUtils.MatcherHintOptions,
	thrown: Thrown,
	expected
)
	local pass = thrown ~= nil and expected:test(thrown.message)

	local message
	if pass then
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				'\n\n' ..
				formatExpected('Expected pattern: never ', expected)

			if thrown ~= nil and thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
				retval = retval .. formatReceived(
					'Received message:       ',
					thrown,
					'message',
					expected
				) .. formatStack(thrown)
			else
				retval = retval ..
					formatReceived('Received value:         ', thrown, 'message') ..
					formatStack(thrown)
			end

			return retval
		end
	else
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				'\n\n' ..
				formatExpected('Expected pattern: ', expected)

			if thrown == nil then
				retval = retval .. '\n' .. DID_NOT_THROW
			else
				if thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
					retval = retval ..
						formatReceived('Received message: ', thrown, 'message') ..
						formatStack(thrown)
				else
					retval = retval ..
						formatReceived('Received value:   ', thrown, 'message') ..
						formatStack(thrown)
				end
			end

			return retval
		end
	end

	return {message = message, pass = pass}
end

type AsymmetricMatcher = {
	asymmetricMatch: (any, any) -> boolean
};

function toThrowExpectedAsymmetric(
	matcherName: string,
	options: JestMatcherUtils.MatcherHintOptions,
	thrown: Thrown,
	expected: AsymmetricMatcher
)
	local pass = thrown ~= nil and expected:asymmetricMatch(thrown.value)

	local message
	if pass then
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n" ..
				formatExpected("Expected asymmetric matcher: never ", expected) ..
				"\n"

			if thrown ~= nil and thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
				retval = retval ..
					formatReceived("Received name:    ", thrown, "name") ..
					formatReceived("Received message: ", thrown, "message") ..
					formatStack(thrown)
			else
				retval = retval ..
					formatReceived("Thrown value: ", thrown, "message") ..
					formatStack(thrown)
			end

			return retval
		end
	else
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n" ..
				formatExpected("Expected asymmetric matcher: ", expected) ..
				"\n"

			if thrown == nil then
				retval = retval .. DID_NOT_THROW
			else
				if thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
					retval = retval ..
						formatReceived("Received name:    ", thrown, "name") ..
						formatReceived("Received message: ", thrown, "message") ..
						formatStack(thrown)
				else
					retval = retval ..
						formatReceived("Thrown value: ", thrown, "message") ..
						formatStack(thrown)
				end
			end

			return retval
		end
	end

	return {message = message, pass = pass}
end

-- deviation: expected does not have Error type annotation
function toThrowExpectedObject(
	matcherName: string,
	options: JestMatcherUtils.MatcherHintOptions,
	thrown: Thrown,
	expected
)
	local pass = thrown ~= nil and thrown.message == expected.message

	local message
	if pass then
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n" ..
				formatExpected("Expected message: never ", expected.message)

			if thrown ~= nil and thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
				retval = retval ..
					formatStack(thrown)
			else
				retval = retval ..
					formatReceived("Received value:         ", thrown, "message") ..
					formatStack(thrown)
			end

			return retval
		end
	else
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n"

			if thrown == nil then
				retval = retval ..
					formatExpected("Expected message: ", expected.message) ..
					"\n" ..
					DID_NOT_THROW
			else
				if thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
					retval = retval ..
						printDiffOrStringify(
							expected.message,
							thrown.message,
							"Expected message",
							"Received message",
							true
						) ..
						"\n" ..
						formatStack(thrown)
				else
					retval = retval ..
						formatExpected("Expected message: ", expected.message) ..
						formatReceived("Received value:   ", thrown, "message") ..
						formatStack(thrown)
				end
			end

			return retval
		end
	end

	return {message = message, pass = pass}
end

-- deviation: expected does not have Function type annotation
function toThrowExpectedClass(
	matcherName: string,
	options: JestMatcherUtils.MatcherHintOptions,
	thrown: Thrown,
	expected
)
	local function isClass(a)
		return a and getmetatable(a) and getmetatable(a).__index
	end

	local pass = thrown ~= nil and thrown.value ~= nil and instanceof(thrown.value, expected)

	local message
	if pass then
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n" ..
				printExpectedConstructorNameNot("Expected constructor", expected)
			if
				thrown ~= nil and
				isClass(thrown.value) and
				isClass(expected) and
				getmetatable(thrown.value).__index ~= expected and
				not thrown.value["$$robloxInternalJestError"] then
					retval = retval ..
						printReceivedConstructorNameNot(
							"Received constructor",
							getmetatable(thrown.value),
							expected
						)
			end

			retval = retval .. "\n"

			if thrown ~= nil and thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
				retval = retval ..
					formatReceived("Received message: ", thrown, "message") ..
					formatStack(thrown)
			else
				retval = retval ..
					formatReceived("Received value: ", thrown, "message") ..
					formatStack(thrown)
			end

			return retval
		end
	else
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n" ..
				printExpectedConstructorName("Expected constructor", expected)

			if thrown == nil then
				retval = retval .. "\n" .. DID_NOT_THROW
			else
				if thrown.value ~= nil and isClass(thrown.value) and not thrown.value["$$robloxInternalJestError"] then
						retval = retval .. printReceivedConstructorName(
							"Received constructor",
							getmetatable(thrown.value)
						)
				end

				retval = retval .. "\n"

				if thrown.hasMessage and not thrown.value["$$robloxInternalJestError"]  then
					retval = retval ..
						formatReceived("Received message: ", thrown, "message") ..
						formatStack(thrown)
				else
					retval = retval ..
						formatReceived("Received value: ", thrown, "message") ..
						formatStack(thrown)
				end
			end

			return retval
		end
	end

	return {message = message, pass = pass}
end

function toThrowExpectedString(
	matcherName: string,
	options: JestMatcherUtils.MatcherHintOptions,
	thrown: Thrown,
	expected: string
)
	local pass = false
	if thrown ~= nil and thrown.message:find(expected, 1, true) then
		pass = true
	end

	local message
	if pass then
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n" ..
				formatExpected("Expected substring: never ", expected)

			if thrown ~= nil and thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
				retval = retval .. formatReceived("Received message:         ", thrown, "message", expected) ..
					formatStack(thrown)
			else
				retval = retval .. formatReceived("Received value:           ", thrown, "message") ..
					formatStack(thrown)
			end

			return retval
		end
	else
		message = function()
			local retval = matcherHint(matcherName, nil, nil, options) ..
				"\n\n" ..
				formatExpected("Expected substring: ", expected)

			if thrown == nil then
				retval = retval .. "\n" .. DID_NOT_THROW
			else
				if thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
					retval = retval .. formatReceived("Received message:   ", thrown, "message") ..
						formatStack(thrown)
				else
					retval = retval .. formatReceived("Received value:     ", thrown, "message") ..
						formatStack(thrown)
				end
			end

			return retval
		end
	end

	return {message = message, pass = pass}
end

function toThrow(
	matcherName: string,
	options,
	thrown: Thrown
)
	local pass = thrown ~= nil

	local message

	if pass then
		message = function()
			local retval =  matcherHint(matcherName, nil, "", options) ..
				"\n\n"

			if thrown ~= nil and thrown.hasMessage and not thrown.value["$$robloxInternalJestError"] then
				retval = retval ..
					formatReceived("Error name:    ", thrown, "name") ..
					formatReceived("Error message: ", thrown, "message") ..
					formatStack(thrown)
			else
				retval = retval ..
					formatReceived("Thrown value: ", thrown, "message") ..
					formatStack(thrown)
			end

			return retval
		end
	else
		message = function()
			return matcherHint(matcherName, nil, "", options) ..
				"\n\n" ..
				DID_NOT_THROW
		end
	end

	return {message = message, pass = pass}
end

function formatExpected(label: string, expected: any)
	return label .. printExpected(expected) .. "\n"
end

-- deviation: expected does not have string | RegExp type annotation
function formatReceived(
	label: string,
	thrown: Thrown,
	key: string,
	expected: any
)
	if thrown == nil then
		return ""
	end

	if key == "message" then
		local message = thrown.message

		if typeof(expected) == "string" then
			local index = message:find(expected)

			if index then
				return
					label ..
					printReceivedStringContainExpectedSubstring(
						message,
						index,
						#expected
					) ..
					"\n"
			end
		elseif getType(expected) == "regexp" then
			-- deviation: we don't check for expected.exec being a function
			-- since all RegExp polyfill instances have this function defined
			return
				label ..
				printReceivedStringContainExpectedResult(
					message,
					expected:exec(message)
			 	) ..
				"\n"
		end

		return label .. printReceived(message) .. "\n";
	end

	if key == "name" then
		if thrown.isError then
			return label .. printReceived(thrown.value.name) .. "\n"
		else
			return ""
		end
	end

	if key == "value" then
		if thrown.isError then
			return ""
		else
			return label .. printReceived(thrown.value) .. "\n"
		end
	end

	return ""
end

function formatStack(thrown: Thrown)
	if thrown == nil or not thrown.isError then
		return ""
	else
		return formatStackTrace(thrown.value.stack)
	end
end


return {
	createMatcher = createMatcher,
	matchers = matchers
}