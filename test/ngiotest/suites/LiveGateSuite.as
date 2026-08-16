/**
 * LiveGateSuite
 *
 * Sits between the offline and live suites and asks before going online.
 *
 * Live testing opens a browser window for Passport sign-in and writes to a real
 * Newgrounds account, so it should not start just because someone pressed
 * Ctrl+Enter. Clicking proceeds; ignoring the prompt abandons the live suites
 * and leaves the offline results readable.
 *
 * Set TestConfig.CONFIRM_BEFORE_LIVE = false to go straight through, or
 * TestConfig.RUN_LIVE_TESTS = false to drop the live suites entirely.
 */
package ngiotest.suites {

    import ngiotest.TestConfig;
    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class LiveGateSuite extends TestSuite {

        /** How long to wait for a decision before assuming "no" */
        private static const DECISION_TIMEOUT_MS:int = 90000;

        public function LiveGateSuite() {
            super();
            // Marked live so that turning live testing off removes the prompt too
            isLive = true;
        }

        override public function get suiteName():String {
            return "Live / Confirmation";
        }

        override public function build():void {

            if (!TestConfig.CONFIRM_BEFORE_LIVE) {
                add("proceeding to live tests without confirmation", function(t:TestContext):void {
                    t.note("TestConfig.CONFIRM_BEFORE_LIVE is false");
                    t.assert(true, "gate disabled");
                    t.done();
                });
                return;
            }

            addSlow("waits for permission to go online", DECISION_TIMEOUT_MS, function(t:TestContext):void {
                var decided:Boolean = false;

                t.prompt(
                    "OFFLINE TESTS FINISHED\n\n" +
                    "Scroll the Output panel to review them.\n\n" +
                    "The live tests contact the Newgrounds gateway, may open a browser\n" +
                    "window to sign in, and write to app '" + TestConfig.APP_ID + "'.\n\n" +
                    "Click below to continue, or wait " + Math.round(DECISION_TIMEOUT_MS / 1000) +
                    " seconds to stop here.",
                    "Run live tests",
                    function():void {
                        decided = true;
                        t.note("live testing confirmed");
                        t.assert(true, "user opted in");
                        t.done();
                    }
                );

                // The runner's watchdog fires if nobody clicks. Rather than let
                // that be recorded as a failure, convert it into a clean stop.
                t.onTimeout = function():void {
                    if (decided) {
                        return;
                    }
                    if (runner != null) {
                        runner.abortLiveSuites();
                    }
                    t.skip("no response - live tests skipped");
                };
            });
        }
    }
}
