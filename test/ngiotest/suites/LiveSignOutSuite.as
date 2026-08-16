/**
 * LiveSignOutSuite
 *
 * Signing out for real: ending the tester's own remembered login server-side and
 * confirming the stored session id is gone and stays gone.
 *
 * NOT THE SAME AS the endSession coverage in LiveGuestSuite. That one ends a
 * throwaway guest session the suite created moments earlier, which proves the
 * component works but says nothing about the thing a game actually does when a
 * player picks "log out": end a real, signed-in, remembered session and stop
 * auto-logging them in next launch. Nothing exercised that, because every other
 * suite is careful to preserve the tester's login.
 *
 * ONLY REGISTERED WHEN A REMEMBERED LOGIN EXISTS. Unlike the no-session and
 * guest states, this precondition cannot be manufactured - a remembered login
 * requires a human to have signed in through Passport with "remember me". So
 * rather than reporting a permanent skip on a machine that has none, the suite
 * is left out of the run entirely; see NgioUnitTest.registerSuites().
 *
 * IT ASKS FIRST, and keeping the login is the default. Signing the tester out
 * unasked would be rude, and an unanswered prompt lands on "keep".
 *
 * PLACED EARLY, before LiveNoSessionSuite, for two reasons. The session has to
 * still be there to end, and signing out at the start means the whole rest of
 * the run then exercises the fresh-machine path - including a genuine Passport
 * sign-in, which is otherwise only covered on a machine that has never logged
 * in.
 */
package ngiotest.suites {

    import io.newgrounds.SessionStatus;
    import io.newgrounds.helpers.AppStateBootstrapHelper;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveSignOutSuite extends LiveSuite {

        /** The session that was ended, so the follow-up case can re-offer it */
        private var endedSessionId:String = null;

        /** Set once the tester has actually chosen to sign out */
        private var didSignOut:Boolean = false;

        /**
         * True when local storage holds a session id for this app.
         *
         * Static and callable BEFORE NGIO.init(), which is the point - the
         * runner decides whether to register this suite at all, and that happens
         * before any live suite has run. Both helpers are plain statics that
         * only touch local storage.
         */
        public static function hasRememberedLogin():Boolean {
            var storageKey:String = AppStateBootstrapHelper.getSessionStorageKey(TestConfig.APP_ID);
            var savedId:String = AppStateBootstrapHelper.getSavedSessionId(storageKey);
            return (savedId != null && savedId.length > 0);
        }

        override public function get suiteName():String {
            return "Live / Sign-out";
        }

        override public function build():void {

            var self:LiveSignOutSuite = this;

            addSlow("signs out of the remembered login on request", TestConfig.INTERACTIVE_TIMEOUT_MS,
                function(t:TestContext):void {

                if (!NGIO.hasSession()) {
                    t.skip("the remembered session id did not survive startup, so there is nothing to end");
                    return;
                }

                // An unanswered prompt is a clean stop, not a failure - the same
                // treatment LiveGateSuite gives its confirmation gate. Keeping
                // the login is the safe default, so a timeout lands there.
                t.onTimeout = function():void {
                    t.skip("nobody chose - keeping the remembered login");
                };

                t.promptChoice(
                    "A REMEMBERED LOGIN WAS FOUND\n\n" +
                    "The rest of this run works fine either way - it parks and restores\n" +
                    "your login rather than disturbing it.\n\n" +
                    "Keep it, and the full sign-out path stays untested.\n" +
                    "Sign out, and App.endSession is tested against a REAL login, the\n" +
                    "stored session id is checked to be gone, and the rest of the run\n" +
                    "exercises the fresh-machine path - including a genuine Passport\n" +
                    "sign-in, which you will have to complete.",

                    "Keep my login",
                    function():void {
                        t.skip("kept the remembered login - the sign-out path is not covered this run");
                    },

                    "Sign out and test it",
                    function():void {
                        self.signOut(t);
                    }
                );
            });

            add("the ended session is no longer accepted by the server", function(t:TestContext):void {
                // The only way to prove endSession did anything SERVER-side.
                //
                // endSession hands its callback nothing and clears local state
                // regardless of what the gateway replied, so every other
                // assertion about it describes the client. This offers the dead
                // id back and checks the server refuses to honour it.
                //
                // A failure here means the session is still live server-side
                // after endSession reported success - which would be worth
                // knowing about urgently.
                if (!self.didSignOut) {
                    t.skip("no sign-out happened, so there is no ended session to re-offer");
                    return;
                }

                // Put the dead id back by hand. checkSession would otherwise
                // just start a fresh session and prove nothing.
                core.appState.session.id = self.endedSessionId;

                self.afterThrottle(function():void {
                    NGIO.checkSession(function(status:SessionStatus):void {
                        if (!t.assertNotNull(status, "checkSession returned a status")) {
                            t.done();
                            return;
                        }

                        t.note("status when re-offering the ended session: " + status.status);

                        // The library recovers from a rejected session by
                        // starting a fresh guest one, so the observable proof is
                        // that we are NOT signed in and NOT holding the old id.
                        t.assertFalse(NGIO.hasUser(),
                            "the ended session does not sign us back in");
                        t.assertNotEquals(self.endedSessionId, core.sessionId,
                            "and the server did not hand the ended id back");

                        t.done();
                    });
                });
            });
        }

        //==================== SIGNING OUT ====================

        /**
         * End the real login and check both halves of what signing out means:
         * the session is gone, and nothing is left remembered on the machine.
         *
         * The storage assertion is the part LiveGuestSuite cannot make. It ends
         * a session it created seconds earlier and then restores the tester's
         * login, so whether anything stays stored depends on the server's
         * `remember` answer. Here nothing is restored, so the answer is
         * unambiguous.
         */
        public function signOut(t:TestContext):void {
            var self:LiveSignOutSuite = this;

            var previousId:String = core.sessionId;
            var storageKey:String = core.appState.sessionStorageKey;

            endedSessionId = previousId;

            NGIO.endSession(function():void {
                didSignOut = true;

                t.assertFalse(NGIO.hasSession(), "no session is held after signing out");
                t.assertFalse(NGIO.hasUser(), "and no user");
                t.assertNull(core.sessionId, "Core reports no session id");

                // The point of this suite: the machine must not auto-log-in next
                // launch.
                var stillStored:String = AppStateBootstrapHelper.getSavedSessionId(storageKey);
                t.assertTrue(stillStored == null || stillStored.length == 0,
                    "the remembered session id was removed from local storage");

                t.note("ended the remembered session " + previousId);
                t.note("the rest of this run now exercises the fresh-machine path, so expect " +
                       "the Passport sign-in prompt later");
                t.done();
            });
        }
    }
}
