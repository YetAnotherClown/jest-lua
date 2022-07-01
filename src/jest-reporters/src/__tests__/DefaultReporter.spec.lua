-- ROBLOX upstream: https://github.com/facebook/jest/blob/v27.4.7/packages/jest-reporters/src/__tests__/DefaultReporter.test.js
--[[*
 * Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 ]]

return function()
	local CurrentModule = script.Parent.Parent
	local Packages = CurrentModule.Parent

	local JestGlobals = require(Packages.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest
	local ModuleMocker = require(Packages.JestMock).ModuleMocker
	local moduleMocker = ModuleMocker.new()

	local DefaultReporter = require(CurrentModule.DefaultReporter).default
	local Writeable = require(Packages.RobloxShared).Writeable

	local aggregatedResults = {}
	local options = {}
	local testCase = { context = { config = { rootDir = "/" } }, duration = 0, path = "/foo" }
	local testResult = {
		snapshot = {
			added = 0,
			fileDeleted = true,
			matched = 1,
			unchecked = 0,
			unmatched = 0,
			updated = 0,
		},
		testFilePath = "/foo",
	}

	local stdoutWrite = moduleMocker:fn()
	local stderrWrite = moduleMocker:fn()

	local process = {
		env = {
			IS_INTERACTIVE = true,
		},
		stdout = Writeable.new({
			write = function(data)
				stdoutWrite(data)
			end,
		}),
		stderr = Writeable.new({
			write = function(data)
				stderrWrite(data)
			end,
		}),
	}

	beforeEach(function()
		jest.useFakeTimers()
		stdoutWrite:mockClear()
		stderrWrite:mockClear()
	end)

	-- ROBLOX deviation START: removed afterEach since we aren't overriding node globals

	it("normal output, everything goes to stdout", function()
		local reporter = DefaultReporter.new({ rootDir = "", useStderr = false }, process)
		reporter:onRunStart(aggregatedResults, options)
		reporter:onTestStart(testCase)
		reporter:onTestResult(testCase, testResult, aggregatedResults)
		reporter:onRunComplete()
		jest.runAllTimers()
		jestExpect(stdoutWrite).toHaveBeenCalled()
	end)

	it("when using stderr as output, no stdout call is made", function()
		local reporter = DefaultReporter.new({ rootDir = "", useStderr = true }, process)
		reporter:onRunStart(aggregatedResults, options)
		reporter:onTestStart(testCase)
		reporter:onTestResult(testCase, testResult, aggregatedResults)
		reporter:onRunComplete()
		jest.runAllTimers()
		jestExpect(stdoutWrite).never.toHaveBeenCalled()
	end)
end