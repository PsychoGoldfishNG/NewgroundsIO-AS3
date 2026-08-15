/**
 * TestRunner
 *
 * Runs suites and their cases strictly one at a time, waiting for each test to
 * call done() before starting the next. Results go to trace(), so they land in
 * the Flash IDE Output panel.
 *
 * Sequencing matters here: live tests share one Core and one session, so
 * running them concurrently would let an unlock race a medal list refresh.
 */
package ngiotest {

    import flash.events.TimerEvent;
    import flash.utils.Timer;

    public class TestRunner {

        //==================== PROPERTIES ====================

        /** Suites queued for execution */
        private var suites:Array = [];

        /** Shared prompt/status UI passed down to every TestContext */
        private var ui:TestUI;

        /** Called with (runner) when every suite has finished */
        private var onComplete:Function;

        /** Index of the suite currently running */
        private var suiteIndex:int = -1;

        /** Index of the case currently running inside the active suite */
        private var caseIndex:int = -1;

        /** The suite currently running */
        private var activeSuite:TestSuite;

        /** Context for the test currently running */
        private var activeContext:TestContext;

        /** Watchdog for the test currently running */
        private var timeoutTimer:Timer;

        /**
         * Trampoline state. A synchronous test calls done() from inside its own
         * invocation, which would otherwise recurse one stack frame deeper per
         * test and blow the stack on a few hundred cases. Instead done() just
         * raises a flag and the loop in pump() picks it up.
         */
        private var pumping:Boolean = false;
        private var advanceRequested:Boolean = false;

        /** Set once the pause before the next live case has been served */
        private var paced:Boolean = false;

        /** Timer for that pause, held so it can be cancelled on abort */
        private var pacingTimer:Timer;

        //==================== TALLIES ====================

        public var passedCount:int = 0;
        public var failedCount:int = 0;
        public var skippedCount:int = 0;
        public var assertionCount:int = 0;

        /** Names of failed tests, repeated in the final summary */
        private var failedNames:Array = [];

        /** Wall-clock start, for a total duration in the summary */
        private var startedAt:Number = 0;

        /** Set when a suite calls abortLiveSuites(); later live suites are skipped */
        private var liveAborted:Boolean = false;

        //==================== CONSTRUCTOR ====================

        public function TestRunner(ui:TestUI) {
            this.ui = ui;
            this.suites = [];
            this.failedNames = [];
        }

        //==================== PUBLIC API ====================

        /**
         * Queue a suite. Live suites are dropped here rather than at run time
         * so they never appear in the report when live testing is off.
         */
        public function addSuite(suite:TestSuite):void {
            if (suite.isLive && !TestConfig.RUN_LIVE_TESTS) {
                return;
            }
            if (!suite.isLive && !TestConfig.RUN_OFFLINE_TESTS) {
                return;
            }
            suites.push(suite);
        }

        /**
         * Abandon every live suite that has not started yet.
         *
         * Used by the confirmation gate when the user declines (or ignores) the
         * prompt to go online. Offline suites are unaffected, and suites already
         * finished keep their results.
         */
        public function abortLiveSuites():void {
            liveAborted = true;
        }

        /**
         * Start running. `onComplete` receives this runner once everything is done.
         */
        public function run(onComplete:Function = null):void {
            this.onComplete = onComplete;
            this.startedAt = new Date().time;

            NetworkLog.resetTotals();

            Reporter.header("NewgroundsIO-AS3 Unit Tests");
            Reporter.line("Gateway:  " + TestConfig.gatewayUrl());
            Reporter.line("App ID:   " + TestConfig.APP_ID);
            Reporter.line("Debug:    " + TestConfig.USE_DEBUG_MODE + "  (debug mode does not persist changes on the server)");
            Reporter.line("Offline:  " + TestConfig.RUN_OFFLINE_TESTS + "     Live: " + TestConfig.RUN_LIVE_TESTS);
            Reporter.blank();

            suiteIndex = -1;
            advanceSuite();
        }

        //==================== SUITE SEQUENCING ====================

        private function advanceSuite():void {
            // Let the previous suite tear down before moving on
            if (activeSuite != null) {
                var finishedSuite:TestSuite = activeSuite;
                activeSuite = null;
                finishedSuite.tearDown(advanceSuite);
                return;
            }

            suiteIndex++;

            if (suiteIndex >= suites.length) {
                finishRun();
                return;
            }

            activeSuite = suites[suiteIndex] as TestSuite;
            caseIndex = -1;

            // A gate suite may have called off the rest of the live run
            if (activeSuite.isLive && liveAborted) {
                Reporter.suite(activeSuite.suiteName);
                Reporter.skip("<entire suite>", "live testing was declined");
                skippedCount++;
                activeSuite = null;
                advanceSuite();
                return;
            }

            activeSuite.runner = this;

            try {
                activeSuite.build();
            } catch (buildError:Error) {
                Reporter.suite(activeSuite.suiteName);
                Reporter.fail("<suite build>", ["build() threw: " + buildError.message]);
                failedCount++;
                failedNames.push(activeSuite.suiteName + " / <suite build>");
                // Skip straight past a suite that could not be assembled
                activeSuite = null;
                advanceSuite();
                return;
            }

            Reporter.suite(activeSuite.suiteName);

            // Say so when a suite runs at its own pace. Otherwise a run that
            // takes 14 seconds longer than the last one looks like the gateway
            // got slower, and a green result here means nothing unless the
            // reader knows the spacing that produced it.
            if (activeSuite.isLive && activeSuite.pacingMs >= 0 &&
                activeSuite.pacingMs != TestConfig.LIVE_TEST_PACING_MS) {
                Reporter.note("this suite is paced at " + activeSuite.pacingMs +
                              "ms between cases, not the usual " + TestConfig.LIVE_TEST_PACING_MS + "ms");
            }

            var self:TestRunner = this;
            try {
                activeSuite.setUp(function():void {
                    self.pump();
                });
            } catch (setupError:Error) {
                Reporter.fail("<suite setUp>", ["setUp() threw: " + setupError.message]);
                failedCount++;
                failedNames.push(activeSuite.suiteName + " / <suite setUp>");
                activeSuite = null;
                advanceSuite();
            }
        }

        //==================== CASE SEQUENCING ====================

        /**
         * Ask the loop to start the next test. Safe to call from inside a test:
         * the flag is picked up by the active pump() rather than recursing.
         */
        private function pump():void {
            advanceRequested = true;

            if (pumping) {
                return;
            }

            pumping = true;
            while (advanceRequested) {
                advanceRequested = false;
                startNextCase();
            }
            pumping = false;
        }

        private function startNextCase():void {
            if (activeSuite == null) {
                return;
            }

            // Space out gateway traffic. Weak medicine - the limit counts
            // connections per window, so pacing does not lower the count. See
            // TestConfig.LIVE_TEST_PACING_MS before relying on it.
            //
            // Returning here leaves pump()'s loop with nothing to do, so it exits
            // cleanly; the timer calls pump() again once the pause is served.
            var pacing:int = (activeSuite.pacingMs >= 0)
                           ? activeSuite.pacingMs
                           : TestConfig.LIVE_TEST_PACING_MS;

            if (activeSuite.isLive && pacing > 0 && !paced) {
                paced = true;
                startPacing(pacing);
                return;
            }
            paced = false;

            caseIndex++;

            if (caseIndex >= activeSuite.cases.length) {
                // Suite exhausted. advanceSuite() handles tearDown.
                advanceSuite();
                return;
            }

            var testCase:TestCase = activeSuite.cases[caseIndex] as TestCase;
            var self:TestRunner = this;

            var context:TestContext = new TestContext(testCase.name, ui, function(finished:TestContext):void {
                self.completeCase(finished);
            });
            activeContext = context;

            var timeoutMs:int = (testCase.timeoutMs > 0) ? testCase.timeoutMs : TestConfig.TEST_TIMEOUT_MS;
            startTimeout(timeoutMs, context);

            // Traffic is recorded per test, so a failure dump shows only the
            // exchanges that belong to it
            NetworkLog.reset();

            try {
                testCase.fn.call(null, context);
            } catch (testError:Error) {
                // A throw is a failure, not a crash - record it and keep going.
                //
                // Held in a local rather than read back from activeContext: a
                // test that calls done() and only then throws has already been
                // completed, which nulls activeContext. Recording against the
                // local keeps that case from turning into a TypeError here, and
                // the isFinished guard stops it being counted twice.
                if (!context.isFinished) {
                    context.fail("threw " + describeError(testError));
                    context.done();
                } else {
                    Reporter.note("after done(), " + testCase.name + " threw " + describeError(testError));
                }
            }
        }

        private function completeCase(context:TestContext):void {
            // Ignore a late done() from a test that already timed out
            if (context !== activeContext) {
                return;
            }

            stopTimeout();
            activeContext = null;

            assertionCount += context.assertionCount;

            if (context.skipped) {
                skippedCount++;
                Reporter.skip(context.name, context.skipReason);
            } else if (context.failures.length > 0) {
                failedCount++;
                failedNames.push(activeSuite.suiteName + " / " + context.name);
                Reporter.fail(context.name, context.failures);

                // Show what actually crossed the wire. Only on failure - doing
                // it for passes would bury the report.
                if (TestConfig.CAPTURE_PACKETS_ON_FAILURE && !NetworkLog.isEmpty) {
                    Reporter.packets(NetworkLog.dump());
                }
            } else {
                passedCount++;
                Reporter.pass(context.name, context.assertionCount);
            }

            for each (var note:String in context.notes) {
                Reporter.note(note);
            }

            if (ui != null) {
                ui.hideButton();
            }

            pump();
        }

        //==================== TIMEOUT WATCHDOG ====================

        /**
         * Waits the given interval, then resumes the runner.
         *
         * Deliberately separate from the per-test watchdog timer: that one is
         * armed for the case currently running, and reusing it would cancel a
         * live test's timeout the moment the next one was queued.
         */
        private function startPacing(milliseconds:int):void {
            stopPacing();

            var self:TestRunner = this;
            pacingTimer = new Timer(milliseconds, 1);
            pacingTimer.addEventListener(TimerEvent.TIMER, function(event:TimerEvent):void {
                self.stopPacing();
                self.pump();
            });
            pacingTimer.start();
        }

        private function stopPacing():void {
            if (pacingTimer != null) {
                pacingTimer.stop();
                pacingTimer = null;
            }
        }

        private function startTimeout(milliseconds:int, context:TestContext):void {
            stopTimeout();

            timeoutTimer = new Timer(milliseconds, 1);
            timeoutTimer.addEventListener(TimerEvent.TIMER, function(event:TimerEvent):void {
                if (context.isFinished) {
                    return;
                }

                // Give the test a chance to treat the timeout as a valid outcome
                if (context.onTimeout != null) {
                    try {
                        context.onTimeout.call(null);
                    } catch (hookError:Error) {
                        context.fail("onTimeout hook threw: " + hookError.message);
                    }
                    if (context.isFinished) {
                        return;
                    }
                }

                context.fail("timed out after " + milliseconds + "ms");
                context.done();
            });
            timeoutTimer.start();
        }

        private function stopTimeout():void {
            if (timeoutTimer != null) {
                timeoutTimer.stop();
                timeoutTimer = null;
            }
        }

        //==================== COMPLETION ====================

        private function finishRun():void {
            var elapsedSeconds:Number = Math.round((new Date().time - startedAt) / 100) / 10;

            Reporter.blank();
            Reporter.header("Summary");
            Reporter.line("Passed:     " + passedCount);
            Reporter.line("Failed:     " + failedCount);
            Reporter.line("Skipped:    " + skippedCount);
            Reporter.line("Assertions: " + assertionCount);
            Reporter.line("Duration:   " + elapsedSeconds + "s");

            // Reported because the gateway limits X connections within Y minutes
            // and the suite is the only thing here that can measure its own draw
            // on that budget. Offline-only runs sit at 0 and the line is quiet.
            if (NetworkLog.totalRequests > 0) {
                Reporter.line("Requests:   " + NetworkLog.totalRequests +
                              " gateway calls (at least - see NetworkLog.totalRequests)");
            }

            if (failedCount > 0) {
                Reporter.blank();
                Reporter.line("Failed tests:");
                for each (var name:String in failedNames) {
                    Reporter.line("  - " + name);
                }
            }

            Reporter.blank();
            Reporter.line(failedCount == 0 ? "RESULT: ALL TESTS PASSED" : "RESULT: " + failedCount + " TEST(S) FAILED");
            Reporter.rule();

            if (ui != null) {
                ui.hideButton();
                ui.setInfo(
                    (failedCount == 0 ? "All tests passed." : failedCount + " test(s) failed.") +
                    "\n\nPassed " + passedCount + " / Failed " + failedCount + " / Skipped " + skippedCount +
                    "\n\nFull results are in the Output panel."
                );
            }

            if (onComplete != null) {
                onComplete.call(null, this);
            }
        }

        //==================== HELPERS ====================

        private function describeError(error:Error):String {
            var text:String = error.message;
            if (error is ArgumentError) {
                return "ArgumentError: " + text;
            }
            if (error is TypeError) {
                return "TypeError: " + text;
            }
            if (error is RangeError) {
                return "RangeError: " + text;
            }
            return "Error: " + text;
        }
    }
}
