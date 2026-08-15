/**
 * LiveLoaderSuite
 *
 * Checks the Loader.* components using their non-redirect form.
 *
 * Every Loader component can either navigate the browser (NGIO.openXxx) or
 * return the url through a callback (NGIO.loadXxx). The tests use the second
 * form on purpose: opening five browser tabs mid-run would be hostile, and the
 * url is what actually needs verifying. The redirect path shares all of its
 * request-building code with the load path, and is exercised once by the
 * Passport sign-in in LiveSessionSuite.
 */
package ngiotest.suites {

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveLoaderSuite extends LiveSuite {

        override public function get suiteName():String {
            return "Live / Loader URLs";
        }

        /**
         * Left at the normal pace - see TestConfig.LOADER_PACING_MS.
         *
         * This suite was slowed down for a while, when the gateway's 429s all
         * appeared to land here. They were not this suite's doing, so the
         * override is back to -1 and kept only as a worked example.
         */
        override public function get pacingMs():int {
            return TestConfig.LOADER_PACING_MS;
        }

        override public function build():void {

            // This suite spent a while under suspicion for the gateway's 429s,
            // because it ran last and every 429 landed in it. It is innocent:
            // run it earlier and it passes, while the failure follows the end of
            // the RUN to whatever component happens to be there. Nothing about
            // Loader.* is rate limited more tightly than the rest of the
            // gateway. See the rate limiting section of test/README.md.
            //
            // The order below is from that investigation. Kept because it costs
            // nothing, and the two loadOfficialUrl calls sitting together makes
            // it obvious they are currently identical - see the note on the
            // second one.

            add("resolves the official url", function(t:TestContext):void {
                // Configured as the project preview page for the test app.
                NGIO.loadOfficialUrl(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "official url");
                });
            });

            add("logging can be suppressed", function(t:TestContext):void {
                // log_stat=false is how a game resolves a url without counting
                // it as a click. It must still return the url.
                //
                // NOTE: identical to the call above - both pass logEvent=false,
                // so this does not currently test what its name claims. Left
                // alone on purpose while the 429 is being investigated: an
                // identical repeat is the thing under suspicion, and changing it
                // would move the repro. Fix once that is settled.
                NGIO.loadOfficialUrl(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "official url with logging off");
                });
            });

            add("reports an unconfigured referral", function(t:TestContext):void {
                // A typo'd referral name should not silently resolve to
                // somewhere arbitrary.
                NGIO.loadReferral("no-such-referral", false, function(url:String, error:*):void {
                    if (error != null) {
                        t.note("server rejected the unknown referral: " + describeError(error));
                        t.assert(true, "unknown referral reported as an error");
                    } else {
                        t.note("server returned url <" + url + "> for an unknown referral");
                        t.assertNull(url, "unknown referral should not resolve to a url");
                    }
                    t.done();
                });
            });

            add("resolves a configured custom referral", function(t:TestContext):void {
                NGIO.loadReferral(TestConfig.CUSTOM_REFERRAL, false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "referral '" + TestConfig.CUSTOM_REFERRAL + "'");
                });
            });

            add("resolves the newgrounds.com url", function(t:TestContext):void {
                NGIO.loadNewgrounds(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "newgrounds url");
                });
            });

            add("resolves the more-games url", function(t:TestContext):void {
                NGIO.loadMoreGames(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "more games url");
                });
            });

            add("resolves the author url", function(t:TestContext):void {
                NGIO.loadAuthorUrl(false, function(url:String, error:*):void {
                    if (assertUrl(t, url, error, "author url", false)) {
                        t.assertTrue(url.indexOf(TestConfig.SITE_DOMAIN) > 0,
                            "points at " + TestConfig.SITE_DOMAIN);
                    }
                    t.done();
                });
            });
        }

        //==================== HELPERS ====================

        /**
         * Shared assertions for a resolved url.
         *
         * @param finish when true, completes the test - pass false if the caller
         *               wants to add assertions of its own first
         * @return true when the url looked valid
         */
        private function assertUrl(t:TestContext, url:String, error:*, label:String, finish:Boolean = true):Boolean {
            var ok:Boolean = false;

            if (assertNoError(t, error, label + " resolved without error")) {
                if (t.assertNotNull(url, label + " returned a url")) {
                    ok = t.assertTrue(url.indexOf("http") == 0, label + " is an absolute url, got <" + url + ">");
                    t.note(label + ": " + url);
                }
            }

            if (finish) {
                t.done();
            }
            return ok;
        }
    }
}
