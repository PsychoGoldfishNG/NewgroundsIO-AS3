/**
 * LiveSessionSuite
 *
 * Establishes the session every later live suite depends on, and is the only
 * suite that needs a human.
 *
 * Runs second, right after LiveGatewaySuite, so that by the time the medal,
 * scoreboard and cloud save suites start there is either a signed-in user or a
 * clear reason there isn't.
 */
package ngiotest.suites {

    import flash.events.TimerEvent;
    import flash.utils.Timer;

    import io.newgrounds.SessionStatus;
    import io.newgrounds.models.objects.User;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveSessionSuite extends LiveSuite {

        /** Poll handle for the Passport wait, kept so it can be stopped */
        private var pollTimer:Timer;

        override public function get suiteName():String {
            return "Live / Session";
        }

        override public function build():void {

            add("obtains a session from the server", function(t:TestContext):void {
                t.status("Contacting Newgrounds for a session...");

                NGIO.checkSession(function(status:SessionStatus):void {
                    if (!t.assertNotNull(status, "checkSession returned a status")) {
                        t.done();
                        return;
                    }

                    t.note("session status: " + status.status);

                    t.assertNotEquals(SessionStatus.ERROR, status.status,
                        "status is not ERROR" + (status.error != null ? " (" + describeError(status.error) + ")" : ""));
                    t.assertTrue(NGIO.hasSession(), "a session id is held locally");
                    t.assertNotNull(core.sessionId, "session id is readable from Core");
                    t.done();
                });
            });

            add("offers a passport url for a guest session", function(t:TestContext):void {
                if (isSignedIn) {
                    t.skip("already signed in, so there is no passport url to offer");
                    return;
                }

                var passportUrl:String = core.appState.session.passport_url;
                if (t.assertNotNull(passportUrl, "passport url supplied by the server")) {
                    t.assertTrue(passportUrl.indexOf("http") == 0, "passport url is absolute");
                    t.note(passportUrl);
                }
                t.done();
            });

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
                        pollForUser(t);
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
            done.call(null);
        }

        //==================== PASSPORT POLLING ====================

        /**
         * Re-check the session on an interval until a user appears.
         *
         * The interval is deliberately longer than NgioAuthHelper's 3 second
         * checkSession throttle - polling faster than the throttle just returns
         * the previous cached answer and never reaches the server.
         */
        private function pollForUser(t:TestContext):void {
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
