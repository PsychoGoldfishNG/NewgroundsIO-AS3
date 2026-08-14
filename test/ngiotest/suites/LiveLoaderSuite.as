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

        override public function build():void {

            add("resolves the official url", function(t:TestContext):void {
                // Configured as the project preview page for the test app.
                NGIO.loadOfficialUrl(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "official url");
                });
            });

            add("resolves the author url", function(t:TestContext):void {
                NGIO.loadAuthorUrl(false, function(url:String, error:*):void {
                    if (assertUrl(t, url, error, "author url", false)) {
                        t.assertTrue(url.indexOf("newgrounds.com") > 0, "points at newgrounds.com");
                    }
                    t.done();
                });
            });

            add("resolves the more-games url", function(t:TestContext):void {
                NGIO.loadMoreGames(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "more games url");
                });
            });

            add("resolves the newgrounds.com url", function(t:TestContext):void {
                NGIO.loadNewgrounds(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "newgrounds url");
                });
            });

            add("resolves a configured custom referral", function(t:TestContext):void {
                NGIO.loadReferral(TestConfig.CUSTOM_REFERRAL, false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "referral '" + TestConfig.CUSTOM_REFERRAL + "'");
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

            add("logging can be suppressed", function(t:TestContext):void {
                // log_stat=false is how a game resolves a url without counting
                // it as a click. It must still return the url.
                NGIO.loadOfficialUrl(false, function(url:String, error:*):void {
                    assertUrl(t, url, error, "official url with logging off");
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
