/**
 * LiveSignInSuite
 *
 * The Passport half of the session flow: get a user attached to the guest
 * session LiveSessionSuite established, then confirm what that gives us.
 *
 * SPLIT OUT OF LiveSessionSuite so LiveGuestSuite can run between them. A guest
 * session only exists between "we have a session" and "a user signed in", and a
 * suite is the unit the runner schedules - so the guest tests could not sit in
 * that window while both halves lived in one suite.
 *
 * This is the only suite that waits on a human.
 */
package ngiotest.suites {

    import flash.events.TimerEvent;
    import flash.utils.Timer;

    import io.newgrounds.SessionStatus;
    import io.newgrounds.helpers.AppStateBootstrapHelper;
    import io.newgrounds.models.objects.Session;
    import io.newgrounds.models.objects.User;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveSignInSuite extends LiveSuite {

        /** Poll handle for the Passport wait, kept so it can be stopped */
        private var pollTimer:Timer;

        override public function get suiteName():String {
            return "Live / Sign-in";
        }

        override public function build():void {

            var self:LiveSignInSuite = this;

            // "offers a passport url for a guest session" lives in
            // LiveGuestSuite, not here. It could only ever run when the tester
            // was NOT already signed in, and this suite is where a user gets
            // attached - so on any machine with a remembered login it reported a
            // permanent skip. The guest suite guarantees a guest session, which
            // is precisely the state that carries a passport_url.

            // Deliberately generous: this test is bounded by how fast a person
            // can sign in, not by the network.
            addSlow("signs in through Passport", TestConfig.INTERACTIVE_TIMEOUT_MS, function(t:TestContext):void {
                if (isSignedIn) {
                    t.note("already signed in as " + user.name);
                    t.assert(true, "session already carries a user");
                    t.done();
                    return;
                }

                if (!TestConfig.REQUIRE_LOGIN) {
                    t.skip("TestConfig.REQUIRE_LOGIN is false");
                    return;
                }

                t.prompt(
                    "SIGN IN REQUIRED\n\n" +
                    "Click below to open the Newgrounds sign-in page in your browser.\n" +
                    "Approve the app, then return here - the test detects it automatically.\n\n" +
                    "(Set TestConfig.REQUIRE_LOGIN = false to skip every test that needs a user.)",
                    "Open Newgrounds sign-in",
                    function():void {
                        if (!NGIO.openPassport()) {
                            t.fail("openPassport() refused to open - no session, or no passport url");
                            t.done();
                            return;
                        }
                        t.status("Waiting for you to finish signing in...\n\nThis test gives up after " +
                                 Math.round(TestConfig.INTERACTIVE_TIMEOUT_MS / 1000) + " seconds.");
                        self.pollForUser(t);
                    }
                );
            });

            add("exposes the signed-in user", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var signedIn:User = user;
                if (t.assertNotNull(signedIn, "getUser() returned a user")) {
                    t.assertIsType(signedIn, User, "is a User model");
                    t.assertTrue(signedIn.id > 0, "user has a real id");
                    t.assertNotNull(signedIn.name, "user has a name");
                    t.assertTrue(signedIn.name.length > 0, "user name is not empty");
                    t.note("signed in as " + signedIn.name + " (id " + signedIn.id + ", supporter=" + signedIn.supporter + ")");
                }

                t.assertTrue(NGIO.hasUser(), "hasUser() agrees");
                t.assertTrue(NGIO.hasSession(), "hasSession() agrees");
                t.done();
            });

            add("saves the session id locally when the server says remember", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                // The auto-login half of the sign-out suite's contract, from the
                // other end: LiveSignOutSuite proves the stored id is REMOVED on
                // sign-out, and this proves it was PUT THERE in the first place -
                // and only when the server asked for it.
                var session:Session = core.appState.session;
                if (!t.assertNotNull(session, "a session object is held")) {
                    t.done();
                    return;
                }

                var storageKey:String = core.appState.sessionStorageKey;
                var storedId:String = AppStateBootstrapHelper.getSavedSessionId(storageKey);
                var hasStored:Boolean = (storedId != null && storedId.length > 0);

                t.note("session.remember = " + session.remember +
                       ", storage " + (hasStored ? "holds an id" : "is empty"));

                // SKIPPED RATHER THAN INVERTED when remember is false, and the
                // reason is not squeamishness - it is that the opposite assertion
                // would be unsound. finalizeSessionPersistenceState only ever
                // WRITES on remember=true; it never clears on false. So an id
                // sitting in storage during a remember=false run may be a
                // perfectly legitimate leftover from an earlier remembered login,
                // and "storage is empty" is not something this run can require.
                //
                // Choosing not to be remembered is a real answer to the question,
                // so it reads as a skip with the reason stated, not a failure.
                if (session.remember !== true) {
                    t.skip("the server did not ask us to remember this session" +
                           (hasStored ? " (an id from an earlier remembered login is still stored)" : ""));
                    return;
                }

                t.assertTrue(hasStored, "a session id was written to local storage");
                t.assertEquals(session.id, storedId, "and it is THIS session's id");
                t.note("this machine will auto-log-in on the next run; " +
                       "the Live / Sign-out suite is what removes it again");
                t.done();
            });

            add("reports LOGGED_IN without another round trip", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                // Once a user is attached, checkSession short-circuits locally.
                // If this ever starts taking a network round trip, every poll
                // during a Passport wait becomes a server request.
                var settledStatus:SessionStatus = null;

                NGIO.checkSession(function(status:SessionStatus):void {
                    settledStatus = status;
                });

                // A local answer means the callback has already run by the time
                // checkSession() returns; a network answer leaves it null.
                if (!t.assertNotNull(settledStatus, "checkSession answered locally, without a round trip")) {
                    t.done();
                    return;
                }

                t.assertEquals(SessionStatus.LOGGED_IN, settledStatus.status, "status is LOGGED_IN");
                t.assertNotNull(settledStatus.user, "status carries the user");
                t.done();
            });

            add("keepAlive pings without disturbing the session", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var beforeId:String = core.sessionId;
                NGIO.keepAlive();

                // keepAlive is fire-and-forget, so give the request a moment and
                // then confirm it did not clear or replace the session.
                var settle:Timer = new Timer(2000, 1);
                settle.addEventListener(TimerEvent.TIMER, function(event:TimerEvent):void {
                    t.assertTrue(NGIO.hasUser(), "still signed in after keepAlive");
                    t.assertEquals(beforeId, core.sessionId, "session id unchanged");
                    t.done();
                });
                settle.start();
            });
        }

        override public function tearDown(done:Function):void {
            stopPolling();
            super.tearDown(done);
        }

        //==================== PASSPORT POLLING ====================

        /**
         * Re-check the session on an interval until a user appears.
         *
         * The interval is deliberately longer than NgioAuthHelper's 3 second
         * checkSession throttle - polling faster than the throttle just returns
         * the previous cached answer and never reaches the server.
         */
        public function pollForUser(t:TestContext):void {
            stopPolling();

            pollTimer = new Timer(TestConfig.SESSION_POLL_INTERVAL_MS);
            pollTimer.addEventListener(TimerEvent.TIMER, function(event:TimerEvent):void {
                if (t.isFinished) {
                    stopPolling();
                    return;
                }

                NGIO.checkSession(function(status:SessionStatus):void {
                    if (t.isFinished) {
                        return;
                    }

                    if (status.status == SessionStatus.LOGGED_IN) {
                        stopPolling();
                        t.assertNotNull(status.user, "signed-in status carries a user");
                        t.note("signed in as " + status.user.name);
                        t.done();
                        return;
                    }

                    if (status.status == SessionStatus.LOGIN_CANCELLED) {
                        stopPolling();
                        t.skip("sign-in was cancelled");
                        return;
                    }

                    if (status.status == SessionStatus.ERROR) {
                        stopPolling();
                        t.fail("sign-in failed: " + describeError(status.error));
                        t.done();
                    }
                });
            });
            pollTimer.start();
        }

        private function stopPolling():void {
            if (pollTimer != null) {
                pollTimer.stop();
                pollTimer = null;
            }
        }
    }
}
