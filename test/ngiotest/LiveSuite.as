/**
 * LiveSuite
 *
 * Base class for suites that talk to the real gateway.
 *
 * All live suites share one NGIO instance, because NGIO is a static facade and
 * calling init() twice logs a warning and keeps the first Core. Sharing is also
 * what the tests want: the session established by the session suite has to be
 * visible to the medal, scoreboard and cloud save suites that follow.
 */
package ngiotest {

    import io.newgrounds.Core;
    import io.newgrounds.models.objects.User;

    public class LiveSuite extends TestSuite {

        /** Guards the one-time NGIO.init() across every live suite */
        private static var didInit:Boolean = false;

        public function LiveSuite() {
            super();
            isLive = true;
        }

        override public function setUp(done:Function):void {
            if (!didInit) {
                NGIO.init(
                    TestConfig.APP_ID,
                    TestConfig.ENCRYPTION_KEY,
                    TestConfig.BUILD_VERSION,
                    TestConfig.USE_DEBUG_MODE
                );

                // Record gateway traffic so a failing test can show it. Attach
                // immediately after init, because init() itself fires App.logView
                // and that exchange is worth having if it goes wrong.
                if (TestConfig.CAPTURE_PACKETS_ON_FAILURE) {
                    NetworkLog.attach(NGIO.core);
                }
                if (TestConfig.TRACE_ALL_PACKETS) {
                    NGIO.core.debugNetworkCalls = true;
                }

                didInit = true;
            }
            done.call(null);
        }

        //==================== SHARED HELPERS ====================

        /** The Core the live suites share */
        protected function get core():Core {
            return NGIO.core;
        }

        /** True when a Newgrounds user is signed in */
        protected function get isSignedIn():Boolean {
            return (NGIO.core != null) && NGIO.hasUser();
        }

        /**
         * Skip the current test when no user is signed in.
         *
         * Session-gated components (medal unlocks, score posts, cloud saves)
         * cannot be exercised as a guest, and reporting them as failures would
         * drown out real regressions on a guest-only run.
         *
         * @return true if the test was skipped and should return immediately
         */
        protected function skipUnlessSignedIn(t:TestContext):Boolean {
            if (!isSignedIn) {
                t.skip("needs a signed-in user");
                return true;
            }
            return false;
        }

        /**
         * Turn whatever the library handed back as an "error" into something
         * readable. Errors arrive as NgioError models, but a transport failure
         * can produce a plain Error or a String.
         */
        protected function describeError(error:*):String {
            if (error == null) {
                return "null";
            }
            if (error is String) {
                return error as String;
            }
            try {
                if (error.hasOwnProperty("code") || error.hasOwnProperty("message")) {
                    return "[" + error.code + "] " + error.message;
                }
            } catch (e:Error) {
            }
            return String(error);
        }

        /**
         * Standard "the call came back clean" assertion.
         *
         * @return true when there was no error, so callers can guard the rest
         *         of their assertions on it
         */
        protected function assertNoError(t:TestContext, error:*, label:String):Boolean {
            if (error == null) {
                return t.assert(true, label);
            }
            t.fail(label + " -- gateway returned " + describeError(error));
            return false;
        }

        /** The signed-in user, or null */
        protected function get user():User {
            return isSignedIn ? (NGIO.getUser() as User) : null;
        }
    }
}
