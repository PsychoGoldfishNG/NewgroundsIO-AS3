/**
 * OfflineWireFormatSuite
 *
 * Builds the exact JSON envelope Core would put on the wire, and reads back
 * canned server replies through the exact path Core uses - without opening a
 * socket.
 *
 * This is where a protocol regression is cheapest to catch. A live test that
 * fails here tells you "the server said no"; this suite tells you which field
 * was wrong.
 */
package ngiotest.suites {

    import com.hurlant.crypto.Crypto;
    import com.hurlant.crypto.symmetric.ICipher;
    import com.hurlant.crypto.symmetric.PKCS5;
    import com.hurlant.util.Base64;

    import flash.utils.ByteArray;

    import io.newgrounds.BaseComponent;
    import io.newgrounds.Core;
    import io.newgrounds.NGJSON;
    import io.newgrounds.helpers.HttpRequestHelper;
    import io.newgrounds.helpers.HttpResponseHelper;
    import io.newgrounds.models.objects.Execute;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.ObjectFactory;
    import io.newgrounds.models.objects.Request;
    import io.newgrounds.models.objects.Response;
    import io.newgrounds.models.objects.SaveSlot;

    import ngiotest.TestConfig;
    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineWireFormatSuite extends TestSuite {

        private var core:Core;

        override public function get suiteName():String {
            return "Offline / Wire format";
        }

        override public function setUp(done:Function):void {
            core = new Core("unit-test:wire", TestConfig.ENCRYPTION_KEY, "1.2.3", true);
            done.call(null);
        }

        override public function build():void {

            //==================== OUTGOING ====================

            add("request envelope carries app_id, debug and execute", function(t:TestContext):void {
                var envelope:Object = buildEnvelope(makeExecute("Gateway", "ping", null), null);

                t.assertEquals("unit-test:wire", envelope.app_id, "app_id");
                t.assertStrictEquals(true, envelope.debug, "debug flag set from Core");
                t.assertNotNull(envelope.execute, "execute present");
                t.assertFalse(envelope.hasOwnProperty("session_id"), "no session_id when there is no session");
                t.done();
            });

            add("request envelope omits debug when it is off", function(t:TestContext):void {
                // The gateway treats the presence of "debug" as the switch, so a
                // literal `debug: false` would still put the app in debug mode.
                var liveCore:Core = new Core("unit-test:live", TestConfig.ENCRYPTION_KEY, null, false);
                var request:Request = new Request();
                request.core = liveCore;
                request.app_id = liveCore.appId;
                request.debug = liveCore.useDebugMode;
                request.setExecute(makeExecute("Gateway", "ping", null, liveCore));

                var envelope:Object = HttpRequestHelper.buildGatewayRequestObject(request);
                t.assertFalse(envelope.hasOwnProperty("debug"), "debug key absent entirely");
                t.done();
            });

            add("request envelope includes session_id when present", function(t:TestContext):void {
                var envelope:Object = buildEnvelope(makeExecute("Gateway", "ping", null), "session-xyz");
                t.assertEquals("session-xyz", envelope.session_id, "session_id passed through");
                t.done();
            });

            add("a plain component serializes as component + parameters", function(t:TestContext):void {
                var envelope:Object = buildEnvelope(makeExecute("ScoreBoard", "getScores", { id: 6510, limit: 10, period: "D" }), null);

                var execute:Object = envelope.execute;
                t.assertEquals("ScoreBoard.getScores", execute.component, "component path");
                t.assertNotNull(execute.parameters, "parameters present");
                t.assertEquals(6510, execute.parameters.id, "id parameter");
                t.assertEquals(10, execute.parameters.limit, "limit parameter");
                t.assertEquals("D", execute.parameters.period, "period parameter");
                t.assertFalse(execute.hasOwnProperty("secure"), "not encrypted");
                t.done();
            });

            add("a secure component serializes as an encrypted blob only", function(t:TestContext):void {
                // Medal.unlock is flagged isSecure. The envelope must expose only
                // {secure: "..."} - leaking the plain component alongside it would
                // defeat the encryption entirely.
                var envelope:Object = buildEnvelope(makeExecute("Medal", "unlock", { id: 4242 }), "session-xyz");
                var execute:Object = envelope.execute;

                t.assertTrue(execute.hasOwnProperty("secure"), "secure key present");
                t.assertFalse(execute.hasOwnProperty("component"), "component name not leaked");
                t.assertFalse(execute.hasOwnProperty("parameters"), "parameters not leaked");

                var inner:Object = NGJSON.parse(decrypt(execute.secure));
                t.assertEquals("Medal.unlock", inner.component, "encrypted component path");
                t.assertEquals(4242, inner.parameters.id, "encrypted parameter");
                t.done();
            });

            add("a queue of components serializes as an execute array", function(t:TestContext):void {
                var request:Request = new Request();
                request.core = core;
                request.app_id = core.appId;
                request.setExecuteList([
                    makeExecute("Gateway", "ping", null),
                    makeExecute("Medal", "getList", null),
                    makeExecute("ScoreBoard", "getBoards", null)
                ]);

                var envelope:Object = HttpRequestHelper.buildGatewayRequestObject(request);
                var executeArray:Array = envelope.execute as Array;

                if (!t.assertNotNull(executeArray, "execute is an array")) {
                    t.done();
                    return;
                }

                t.assertEquals(3, executeArray.length, "all three components present");
                t.assertEquals("Gateway.ping", executeArray[0].component, "first component");
                t.assertEquals("Medal.getList", executeArray[1].component, "second component");
                t.assertEquals("ScoreBoard.getBoards", executeArray[2].component, "third component");
                t.done();
            });

            add("a mixed queue encrypts only the secure entries", function(t:TestContext):void {
                var request:Request = new Request();
                request.core = core;
                request.app_id = core.appId;
                request.setExecuteList([
                    makeExecute("Gateway", "ping", null),
                    makeExecute("Medal", "unlock", { id: 1 })
                ]);

                var executeArray:Array = HttpRequestHelper.buildGatewayRequestObject(request).execute as Array;

                t.assertEquals("Gateway.ping", executeArray[0].component, "plain entry stays plain");
                t.assertTrue(executeArray[1].hasOwnProperty("secure"), "secure entry is encrypted");
                t.done();
            });

            add("the whole envelope survives JSON encoding", function(t:TestContext):void {
                var envelope:Object = buildEnvelope(makeExecute("Medal", "unlock", { id: 7 }), "session-xyz");
                var json:String = NGJSON.stringify(envelope);
                var reparsed:Object = NGJSON.parse(json);

                t.assertEquals("unit-test:wire", reparsed.app_id, "app_id survived");
                t.assertEquals("session-xyz", reparsed.session_id, "session_id survived");
                t.assertTrue(reparsed.execute.hasOwnProperty("secure"), "secure blob survived");
                t.assertEquals(7, NGJSON.parse(decrypt(reparsed.execute.secure)).parameters.id,
                    "and still decrypts after the JSON round-trip");
                t.done();
            });

            add("Execute rejects having both component and secure", function(t:TestContext):void {
                var execute:Execute = new Execute();
                t.assertFalse(execute.hasValidProperties(), "neither set is invalid");

                execute.component = "Medal.unlock";
                t.assertTrue(execute.hasValidProperties(), "component alone is valid");

                execute.secure = "abc";
                t.assertFalse(execute.hasValidProperties(), "both set is invalid");

                execute.component = null;
                t.assertTrue(execute.hasValidProperties(), "secure alone is valid");
                t.done();
            });

            //==================== INCOMING ====================

            add("parses a single-result response into a typed result", function(t:TestContext):void {
                var response:Response = importResponse(
                    '{"app_id":"unit-test:wire","success":true,' +
                    '"result":{"component":"Gateway.ping","data":{"success":true,"pong":"pong"}}}'
                );

                t.assertTrue(response.success, "response success");
                t.assertFalse(response.resultIsList(), "single result, not a list");

                var result:* = response.getResult();
                if (t.assertNotNull(result, "result created")) {
                    t.assertEquals("Gateway.ping", result.objectName, "typed as Gateway.ping");
                    t.assertTrue(result.success, "result success");
                }
                t.done();
            });

            add("parses a multi-result response into a list", function(t:TestContext):void {
                var response:Response = importResponse(
                    '{"app_id":"unit-test:wire","success":true,"result":[' +
                    '{"component":"Gateway.ping","data":{"success":true}},' +
                    '{"component":"Medal.getList","data":{"success":true,"medals":[{"id":1,"name":"A","value":5}]}}' +
                    ']}'
                );

                t.assertTrue(response.resultIsList(), "reports a list");

                var results:Array = response.getResultList();
                if (!t.assertNotNull(results, "result list created")) {
                    t.done();
                    return;
                }

                t.assertEquals(2, results.length, "both results present");
                t.assertEquals("Gateway.ping", results[0].objectName, "first is Gateway.ping");
                t.assertEquals("Medal.getList", results[1].objectName, "second is Medal.getList");

                var medals:Array = results[1].medals as Array;
                if (t.assertNotNull(medals, "nested medals parsed")) {
                    t.assertEquals(1, medals.length, "one medal");
                    t.assertIsType(medals[0], Medal, "medal is typed");
                    t.assertEquals("A", (medals[0] as Medal).name, "medal name");
                }
                t.done();
            });

            add("parses nested objects inside a result", function(t:TestContext):void {
                var response:Response = importResponse(
                    '{"success":true,"result":{"component":"App.checkSession","data":{"success":true,' +
                    '"session":{"id":"sess-1","expired":false,"user":{"id":42,"name":"Tester","supporter":true}}}}}'
                );

                var result:* = response.getResult();
                if (!t.assertNotNull(result, "result created")) {
                    t.done();
                    return;
                }

                var session:* = result.session;
                if (t.assertNotNull(session, "session parsed")) {
                    t.assertEquals("sess-1", session.id, "session id");
                    if (t.assertNotNull(session.user, "user parsed")) {
                        t.assertEquals(42, session.user.id, "user id");
                        t.assertEquals("Tester", session.user.name, "user name");
                        t.assertTrue(session.user.supporter, "supporter flag");
                    }
                }
                t.done();
            });

            add("parses an array-of-SaveSlot result", function(t:TestContext):void {
                var response:Response = importResponse(
                    '{"success":true,"result":{"component":"CloudSave.loadSlots","data":{"success":true,"slots":[' +
                    '{"id":1,"size":128,"datetime":"2026-01-01T00:00:00+00:00","timestamp":1767225600,"url":"//example.com/1"},' +
                    '{"id":2,"size":0}' +
                    ']}}}'
                );

                var slots:Array = response.getResult().slots as Array;
                if (!t.assertNotNull(slots, "slots parsed")) {
                    t.done();
                    return;
                }

                t.assertEquals(2, slots.length, "two slots");
                t.assertIsType(slots[0], SaveSlot, "slot is typed");
                t.assertEquals(128, (slots[0] as SaveSlot).size, "slot size");
                t.assertTrue((slots[0] as SaveSlot).hasData(), "slot with a url has data");
                t.assertFalse((slots[1] as SaveSlot).hasData(), "slot without a url has no data");
                t.done();
            });

            add("propagates a response-level error onto the result", function(t:TestContext):void {
                // A request-level failure has no per-result error, but callers
                // check result.error. Without propagation they see a null error
                // on a failed call and report success.
                var response:Response = importResponse(
                    '{"success":false,"error":{"message":"Invalid App ID.","code":200},' +
                    '"result":{"component":"Gateway.ping","data":{"success":false}}}'
                );

                if (t.assertNotNull(response.error, "response error parsed")) {
                    t.assertEquals(200, response.error.code, "response error code");
                }

                var result:* = response.getResult();
                if (t.assertNotNull(result, "result present")) {
                    t.assertNotNull(result.error, "error pushed down to the result");
                    t.assertEquals(200, result.error.code, "same code on the result");
                }
                t.done();
            });

            add("keeps a result's own error rather than overwriting it", function(t:TestContext):void {
                var response:Response = importResponse(
                    '{"success":false,"error":{"message":"outer","code":200},' +
                    '"result":{"component":"Medal.unlock","data":{"success":false,"error":{"message":"inner","code":202}}}}'
                );

                var result:* = response.getResult();
                if (t.assertNotNull(result.error, "result kept an error")) {
                    t.assertEquals(202, result.error.code, "the result's own error wins");
                }
                t.done();
            });

            add("ignores result entries the factory cannot type", function(t:TestContext):void {
                // A future gateway component this build has never heard of must not
                // take the whole response down with it.
                var response:Response = importResponse(
                    '{"success":true,"result":[' +
                    '{"component":"Gateway.ping","data":{"success":true}},' +
                    '{"component":"Future.method","data":{"success":true}},' +
                    '{"component":"malformed","data":{"success":true}}' +
                    ']}'
                );

                var results:Array = response.getResultList();
                if (t.assertNotNull(results, "surviving results returned")) {
                    t.assertEquals(1, results.length, "only the known component survived");
                    t.assertEquals("Gateway.ping", results[0].objectName, "and it is the right one");
                }
                t.done();
            });

            add("survives a failed component that returns no payload", function(t:TestContext):void {
                // Regression test. A rejected Medal.unlock returns an error and no
                // 'medal', and AppState's merge used to read medal.id straight off
                // that null. The throw escaped applyResult(), so Core reported a
                // generic "invalid response" (505) instead of the server's real 202,
                // the session bookkeeping at the end of applyResult never ran, and in
                // a batch every result after the failing one was silently dropped.
                var syncCore:Core = new Core("unit-test:nullpayload", TestConfig.ENCRYPTION_KEY);

                // Populate the medal cache first - the crash only reached the merge
                // when there was an existing collection to merge into.
                var seed:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(seed, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.getList","data":{"success":true,"medals":[' +
                    '{"id":10,"name":"Alpha","value":5}]}}}'
                ));
                t.assertEquals(1, syncCore.appState.medals.length, "medal cached for the merge to find");

                var response:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(response, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.unlock","data":{"success":false,' +
                    '"error":{"message":"The medal id (99999999) does not match any medals for this app.","code":202}}}}'
                ));

                // Reaching here at all is most of the test - it used to throw.
                var result:* = response.getResult();
                if (t.assertNotNull(result, "result model built")) {
                    t.assertFalse(result.success, "result reports failure");
                    if (t.assertNotNull(result.error, "the server's own error survived")) {
                        t.assertEquals(202, result.error.code, "and it is the real 202, not a generic 505");
                    }
                }

                t.assertNull(response.error, "no spurious response-level error was invented");
                t.assertEquals(1, syncCore.appState.medals.length, "cached medals left intact");
                t.assertFalse(syncCore.appState.hasLoaded("medalScore"),
                    "a rejected unlock does not mark medalScore as loaded");
                t.assertEquals(0, syncCore.appState.medalScore, "and does not overwrite the cached score");
                t.done();
            });

            add("a failed list component does not cache an empty result", function(t:TestContext):void {
                // Same family: caching the missing payload and marking it loaded
                // would make hasLoaded() report true for data that never arrived,
                // which silences the "call loadMedals() first" warning.
                var syncCore:Core = new Core("unit-test:failedlist", TestConfig.ENCRYPTION_KEY);

                var response:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(response, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.getList","data":{"success":false,' +
                    '"error":{"message":"You must be logged in to do that.","code":110}}}}'
                ));

                t.assertNull(syncCore.appState.medals, "nothing cached");
                t.assertFalse(syncCore.appState.hasLoaded("medals"), "and not reported as loaded");
                t.done();
            });

            add("does not cache medals loaded from another app", function(t:TestContext):void {
                // Medal.getList accepts an app_id, letting an approved app read a
                // different app's medals. The result echoes that id back. Those
                // medals belong to somebody else and must not become ours -
                // otherwise NGIO.getMedals() starts returning the wrong game's
                // medals, and hasLoaded('medals') claims they are ours.
                var syncCore:Core = new Core("unit-test:crossapp", TestConfig.ENCRYPTION_KEY);

                var foreign:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(foreign, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.getList","data":{"success":true,' +
                    '"app_id":"39685:NJ1KkPGb","medals":[{"id":900,"name":"Foreign","value":5}]}}}'
                ));

                t.assertNull(syncCore.appState.medals, "foreign medals were not cached");
                t.assertFalse(syncCore.appState.hasLoaded("medals"), "and medals are not marked loaded");

                // The caller still gets the data - it is only barred from AppState
                var result:* = foreign.getResult();
                if (t.assertNotNull(result, "the caller still receives the result")) {
                    t.assertEquals(1, (result.medals as Array).length, "with the foreign medals intact");
                    t.assertEquals("39685:NJ1KkPGb", result.app_id, "and the source app id");
                }
                t.done();
            });

            add("a foreign medal list cannot overwrite a loaded local one", function(t:TestContext):void {
                var syncCore:Core = new Core("unit-test:crossapp2", TestConfig.ENCRYPTION_KEY);

                // Load our own medals first
                var local:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(local, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.getList","data":{"success":true,"medals":[' +
                    '{"id":10,"name":"Ours","value":5}]}}}'
                ));
                t.assertEquals(1, syncCore.appState.medals.length, "local medals cached");

                // Then read another app's - this used to merge straight over the top
                var foreign:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(foreign, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.getList","data":{"success":true,' +
                    '"app_id":"39685:NJ1KkPGb","medals":[{"id":10,"name":"Theirs","value":999}]}}}'
                ));

                t.assertEquals(1, syncCore.appState.medals.length, "medal count unchanged");
                t.assertEquals("Ours", syncCore.appState.medals[0].name, "our medal was not renamed");
                t.assertEquals(5, syncCore.appState.medals[0].value, "our medal kept its value");
                t.done();
            });

            add("does not cache save slots loaded from another app", function(t:TestContext):void {
                // The quieter half of the same problem: cloud save slots are
                // per-app, so a foreign slot list overwriting ours would have the
                // game reading and writing against the wrong slot metadata.
                var syncCore:Core = new Core("unit-test:crossapp3", TestConfig.ENCRYPTION_KEY);

                var foreign:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(foreign, NGJSON.parse(
                    '{"success":true,"result":{"component":"CloudSave.loadSlots","data":{"success":true,' +
                    '"app_id":"39685:NJ1KkPGb","slots":[{"id":1,"size":99,"url":"//example.com/theirs"}]}}}'
                ));

                t.assertNull(syncCore.appState.saveSlots, "foreign slots were not cached");
                t.assertFalse(syncCore.appState.hasLoaded("saveSlots"), "and slots are not marked loaded");
                t.done();
            });

            add("still caches results that carry our own app id", function(t:TestContext):void {
                // The guard keys off "is this a different app", not merely "is
                // app_id present" - so a gateway that echoed our own id on every
                // call must not switch off caching entirely.
                var syncCore:Core = new Core("61512:1uYiEl7d", TestConfig.ENCRYPTION_KEY);

                var response:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(response, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.getList","data":{"success":true,' +
                    '"app_id":"61512:1uYiEl7d","medals":[{"id":10,"name":"Ours","value":5}]}}}'
                ));

                if (t.assertNotNull(syncCore.appState.medals, "our own medals were cached")) {
                    t.assertEquals(1, syncCore.appState.medals.length, "one medal cached");
                }
                t.assertTrue(syncCore.appState.hasLoaded("medals"), "and marked loaded");
                t.done();
            });

            add("synchronises parsed results into AppState", function(t:TestContext):void {
                // The response path is what actually populates NGIO.getMedals().
                var syncCore:Core = new Core("unit-test:sync", TestConfig.ENCRYPTION_KEY);
                t.assertFalse(syncCore.appState.hasLoaded("medals"), "medals start unloaded");

                var response:Response = ObjectFactory.CreateObject("Response", null, syncCore) as Response;
                HttpResponseHelper.importResponseObject(response, NGJSON.parse(
                    '{"success":true,"result":{"component":"Medal.getList","data":{"success":true,"medals":[' +
                    '{"id":10,"name":"Alpha","value":5},{"id":20,"name":"Beta","value":10}]}}}'
                ));

                t.assertTrue(syncCore.appState.hasLoaded("medals"), "medals marked as loaded");
                if (t.assertNotNull(syncCore.appState.medals, "medals cached on AppState")) {
                    t.assertEquals(2, syncCore.appState.medals.length, "both medals cached");
                }
                t.done();
            });
        }

        //==================== HELPERS ====================

        /**
         * Wrap a component the way Core.executeComponent() does.
         */
        private function makeExecute(component:String, method:String, params:Object, useCore:Core = null):Execute {
            var target:Core = (useCore != null) ? useCore : core;
            var componentModel:BaseComponent = ObjectFactory.CreateComponent(component, method, params, target);

            var execute:Execute = ObjectFactory.CreateObject("Execute", null, target) as Execute;
            execute.core = target;
            execute.setComponent(componentModel);
            return execute;
        }

        /**
         * Build the gateway envelope for a single Execute, as Core.sendRequest() would.
         */
        private function buildEnvelope(execute:Execute, sessionId:String):Object {
            var request:Request = ObjectFactory.CreateObject("Request", null, core) as Request;
            request.core = core;
            request.app_id = core.appId;
            request.debug = core.useDebugMode;
            if (sessionId != null) {
                request.session_id = sessionId;
            }
            request.setExecute(execute);

            return HttpRequestHelper.buildGatewayRequestObject(request);
        }

        /**
         * Feed raw server JSON through the same importer Core uses on a 200.
         */
        private function importResponse(json:String):Response {
            var response:Response = ObjectFactory.CreateObject("Response", null, core) as Response;
            HttpResponseHelper.importResponseObject(response, NGJSON.parse(json));
            return response;
        }

        private function decrypt(base64Text:String):String {
            var keyBytes:ByteArray = Base64.decodeToByteArray(TestConfig.ENCRYPTION_KEY);
            var cipher:ICipher = Crypto.getCipher("simple-aes-cbc", keyBytes, new PKCS5());

            var data:ByteArray = Base64.decodeToByteArray(base64Text);
            cipher.decrypt(data);

            data.position = 0;
            return data.readUTFBytes(data.length);
        }
    }
}
