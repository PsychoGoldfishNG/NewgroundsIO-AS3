/**
 * OfflineBaseObjectSuite
 *
 * Exercises BaseObject's import/export machinery, which every model in the
 * library inherits. If this suite is wrong, everything downstream is wrong.
 */
package ngiotest.suites {

    import io.newgrounds.BaseComponent;
    import io.newgrounds.BaseObject;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.NgioError;
    import io.newgrounds.models.objects.ObjectFactory;
    import io.newgrounds.models.objects.Session;
    import io.newgrounds.models.objects.User;
    import io.newgrounds.NGJSON;

    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineBaseObjectSuite extends TestSuite {

        override public function get suiteName():String {
            return "Offline / BaseObject";
        }

        override public function build():void {

            add("imports scalar properties onto a model", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.importFromObject({
                    id: 12345,
                    name: "Test Medal",
                    description: "A test medal",
                    icon: "https://example.com/icon.webp",
                    value: 50,
                    difficulty: 3,
                    secret: false,
                    unlocked: true
                });

                t.assertEquals(12345, medal.id, "id");
                t.assertEquals("Test Medal", medal.name, "name");
                t.assertEquals("A test medal", medal.description, "description");
                t.assertEquals("https://example.com/icon.webp", medal.icon, "icon");
                t.assertEquals(50, medal.value, "value");
                t.assertEquals(3, medal.difficulty, "difficulty");
                t.assertFalse(medal.secret, "secret");
                t.assertTrue(medal.unlocked, "unlocked");
                t.done();
            });

            add("coerces JSON values to the declared property type", function(t:TestContext):void {
                // The gateway is loosely typed - numeric fields have historically
                // arrived as strings. Assignment through a typed property should
                // coerce rather than store the string.
                var medal:Medal = new Medal();
                medal.importFromObject({ id: "42", value: "5", unlocked: 1 });

                t.assertStrictEquals(42, medal.id, "numeric string coerces to Number");
                t.assertIsType(medal.id, Number, "id is a Number");
                t.assertStrictEquals(5, medal.value, "value coerces");
                t.assertStrictEquals(true, medal.unlocked, "truthy value coerces to Boolean");
                t.done();
            });

            add("resets omitted properties to their defaults", function(t:TestContext):void {
                // Importing is a replace, not a merge: leftovers from a previous
                // import must not survive, or a re-fetched medal would keep an
                // unlocked flag the server no longer reports.
                var medal:Medal = new Medal();
                medal.unlocked = true;
                medal.name = "stale name";
                medal.value = 999;

                medal.importFromObject({ id: 5 });

                t.assertEquals(5, medal.id, "provided property is set");
                t.assertNull(medal.name, "omitted String resets to null");
                t.assertStrictEquals(false, medal.unlocked, "omitted Boolean resets to false");
                t.assertStrictEquals(0, medal.value, "omitted Number resets to 0");
                t.done();
            });

            add("casts a nested object using castTypes", function(t:TestContext):void {
                var session:Session = new Session();
                session.importFromObject({
                    id: "session-abc",
                    expired: false,
                    user: { id: 54321, name: "TestUser", supporter: true }
                });

                t.assertEquals("session-abc", session.id, "session id");
                if (t.assertNotNull(session.user, "user was created")) {
                    t.assertIsType(session.user, User, "user is a User instance");
                    t.assertEquals(54321, session.user.id, "user id");
                    t.assertEquals("TestUser", session.user.name, "user name");
                    t.assertTrue(session.user.supporter, "user supporter");
                }
                t.done();
            });

            add("casts array-of-X into typed instances", function(t:TestContext):void {
                var result:BaseObject = ObjectFactory.CreateResult("Medal", "getList", {
                    success: true,
                    medals: [
                        { id: 1, name: "First", value: 5 },
                        { id: 2, name: "Second", value: 10 }
                    ]
                });

                if (!t.assertNotNull(result, "getListResult created")) {
                    t.done();
                    return;
                }

                var medals:Array = result["medals"] as Array;
                if (!t.assertNotNull(medals, "medals array populated")) {
                    t.done();
                    return;
                }

                t.assertEquals(2, medals.length, "medal count");
                t.assertIsType(medals[0], Medal, "element 0 is a Medal");
                t.assertIsType(medals[1], Medal, "element 1 is a Medal");
                t.assertEquals("First", (medals[0] as Medal).name, "element 0 name");
                t.assertEquals(10, (medals[1] as Medal).value, "element 1 value");
                t.done();
            });

            add("wraps a lone object in an array for array-of-X", function(t:TestContext):void {
                // The gateway collapses single-element lists to a bare object.
                // Callers still expect an Array, so the cast has to re-wrap it.
                var result:BaseObject = ObjectFactory.CreateResult("Medal", "getList", {
                    success: true,
                    medals: { id: 7, name: "Only", value: 25 }
                });

                if (!t.assertNotNull(result, "getListResult created")) {
                    t.done();
                    return;
                }

                var medals:Array = result["medals"] as Array;
                if (!t.assertNotNull(medals, "lone object became an array")) {
                    t.done();
                    return;
                }

                t.assertEquals(1, medals.length, "array holds one entry");
                t.assertIsType(medals[0], Medal, "entry is a Medal");
                t.assertEquals("Only", (medals[0] as Medal).name, "entry name");
                t.done();
            });

            add("builds an NgioError from an error payload", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.importFromObject({
                    id: 1,
                    error: { code: 104, message: "Your session has expired." }
                });

                if (t.assertNotNull(medal.error, "error object created")) {
                    t.assertIsType(medal.error, NgioError, "error is an NgioError");
                    t.assertEquals(104, medal.error.code, "error code");
                    t.assertEquals("Your session has expired.", medal.error.message, "error message");
                }
                t.done();
            });

            add("toObject() drops nulls when asked", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.id = 3;

                var lean:Object = medal.toObject(true, true);
                t.assertEquals(3, lean.id, "id survives");
                t.assertFalse(lean.hasOwnProperty("name"), "null name omitted");
                t.assertFalse(lean.hasOwnProperty("description"), "null description omitted");
                t.assertTrue(lean.hasOwnProperty("value"), "zero Number kept - 0 is a real value");
                t.assertTrue(lean.hasOwnProperty("secret"), "false Boolean kept - false is a real value");
                t.done();
            });

            add("toObject() keeps nulls when asked", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.id = 3;

                var full:Object = medal.toObject(false, false);
                t.assertTrue(full.hasOwnProperty("name"), "null name present");
                t.assertNull(full.name, "null name is null");
                t.assertEquals(8, countKeys(full), "every declared property present");
                t.done();
            });

            add("toObject() flattens nested models recursively", function(t:TestContext):void {
                var session:Session = new Session();
                session.id = "abc";
                session.user = new User();
                session.user.id = 9;
                session.user.name = "Nested";

                var flat:Object = session.toObject(true, true);
                t.assertNotNull(flat.user, "user present");
                t.assertFalse(flat.user is User, "nested model became a plain Object");
                t.assertEquals("Nested", flat.user.name, "nested value survived");
                t.done();
            });

            add("toJsonString() produces parseable JSON", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.id = 11;
                medal.name = 'Quote " and \\ backslash';
                medal.value = 5;

                var json:String = medal.toJsonString();
                t.assertNotNull(json, "json produced");

                var reparsed:Object = NGJSON.parse(json);
                t.assertEquals(11, reparsed.id, "id round-tripped");
                t.assertEquals('Quote " and \\ backslash', reparsed.name, "escapes round-tripped");
                t.done();
            });

            add("imports from another BaseObject of the same type", function(t:TestContext):void {
                var source:Medal = new Medal();
                source.id = 77;
                source.name = "Source";
                source.unlocked = true;

                var target:Medal = new Medal();
                target.importFromObject(source);

                t.assertEquals(77, target.id, "id copied");
                t.assertEquals("Source", target.name, "name copied");
                t.assertTrue(target.unlocked, "unlocked copied");
                t.done();
            });

            add("refuses to import a mismatched model type", function(t:TestContext):void {
                var user:User = new User();
                user.id = 1;

                var medal:Medal = new Medal();
                t.assertThrows(function():void {
                    medal.importFromObject(user);
                }, "importing a User into a Medal should throw");
                t.done();
            });

            add("refuses to import an Array", function(t:TestContext):void {
                var medal:Medal = new Medal();
                t.assertThrows(function():void {
                    medal.importFromObject([1, 2, 3]);
                }, "importing an Array should throw");
                t.done();
            });

            add("ignores null and undefined imports", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.id = 4;

                medal.importFromObject(null);
                t.assertEquals(4, medal.id, "null import left the model untouched");

                medal.importFromObject(undefined);
                t.assertEquals(4, medal.id, "undefined import left the model untouched");
                t.done();
            });

            add("getFullObjectName() qualifies by type", function(t:TestContext):void {
                t.assertEquals("object.Medal", new Medal().getFullObjectName(), "object model");
                t.assertEquals("object.Error", new NgioError().getFullObjectName(), "NgioError reports as Error");

                var component:BaseComponent = ObjectFactory.CreateComponent("Medal", "unlock");
                t.assertEquals("component.Medal.unlock", component.getFullObjectName(), "component model");
                t.done();
            });

            add("import stamps a child's position, and getFullObjectName() stays flat", function(t:TestContext):void {
                // parent and parentPropertyName used to be dead - declared,
                // documented, and never assigned by anything in either library.
                // importFromObject now stamps them via stampChildPosition() as it
                // casts each nested value.
                //
                // The pair feeds getObjectPath(), NOT getFullObjectName(). That
                // split is load-bearing and this test exists to keep it:
                // importFromObject uses getFullObjectName() as a TYPE CHECK when it
                // imports a nested value into a standalone one -
                // AppStateResultUpdateHelper lifts result.session into
                // appState.session that way. Make the name positional and that check
                // compares "object.Session" against "object.checkSessionResult.session"
                // and session handling breaks.
                var session:Session = new Session();
                session.importFromObject({
                    id: "abc",
                    user: { id: 1, name: "Nested" }
                });

                if (!t.assertNotNull(session.user, "nested user imported")) {
                    t.done();
                    return;
                }

                t.assertStrictEquals(session, session.user.parent, "import set parent to the containing model");
                t.assertEquals("user", session.user.parentPropertyName, "import recorded the property it arrived on");

                // Type identity - unchanged by nesting, and deliberately so.
                t.assertEquals("object.User", session.user.getFullObjectName(),
                    "getFullObjectName() still answers WHAT it is, not where it sits");

                // Position - the hierarchical name lives here instead.
                t.assertEquals("object.Session.user", session.user.getObjectPath(),
                    "getObjectPath() answers WHERE it sits");
                t.assertEquals("object.Session", session.getObjectPath(),
                    "an unparented model's path is just its own type name");
                t.done();
            });

            add("array elements are stamped with their index", function(t:TestContext):void {
                var result:Object = ObjectFactory.CreateResult("Medal", "getList", {
                    success: true,
                    medals: [
                        { id: 1, name: "First" },
                        { id: 2, name: "Second" }
                    ]
                });

                if (!t.assertNotNull(result, "getListResult created")) {
                    t.done();
                    return;
                }

                var medals:Array = result["medals"];

                if (!t.assert(medals != null && medals.length == 2, "both medals imported")) {
                    t.done();
                    return;
                }

                t.assertStrictEquals(result, medals[0].parent, "element 0 points at the containing result");
                t.assertEquals("medals[0]", medals[0].parentPropertyName, "element 0 records its index");
                t.assertEquals("medals[1]", medals[1].parentPropertyName, "element 1 records its index");

                t.assertEquals("object.Medal", medals[1].getFullObjectName(),
                    "type identity is unaffected by living in an array");
                t.assertEquals("result.Medal.getList.medals[1]", medals[1].getObjectPath(),
                    "the path names the slot the medal arrived in");
                t.done();
            });

            add("validates required properties", function(t:TestContext):void {
                // Event.logEvent requires host + event_name, both Strings that
                // default to null, so a fresh instance must be invalid.
                var component:BaseComponent = ObjectFactory.CreateComponent("Event", "logEvent");
                if (!t.assertNotNull(component, "logEvent component created")) {
                    t.done();
                    return;
                }

                t.assertFalse(component.hasValidProperties(), "fresh component is invalid");
                t.assertEquals(2, component.getValidationErrors().length, "two missing properties reported");

                component["host"] = "localhost";
                t.assertFalse(component.hasValidProperties(), "still invalid with one property set");
                t.assertEquals(1, component.getValidationErrors().length, "one missing property reported");

                component["event_name"] = "test";
                t.assertTrue(component.hasValidProperties(), "valid once both are set");
                t.assertEquals(0, component.getValidationErrors().length, "no errors reported");
                t.done();
            });

            add("treats an empty string as a missing required property", function(t:TestContext):void {
                var component:BaseComponent = ObjectFactory.CreateComponent("Event", "logEvent");
                component["host"] = "";
                component["event_name"] = "test";

                t.assertFalse(component.hasValidProperties(), "empty string does not satisfy a requirement");

                var errors:Array = component.getValidationErrors();
                t.assertEquals(1, errors.length, "one error reported");
                t.assertTrue(String(errors[0]).indexOf("empty string") >= 0, "error explains it is empty, not missing");
                t.done();
            });

            add("treats zero as a valid required value", function(t:TestContext):void {
                // ScoreBoard.getScores requires id, a Number defaulting to 0, and
                // unlike Medal.unlock it does not also require a session - so this
                // isolates the "is 0 missing?" question. Rejecting 0 would make
                // board id 0 permanently unusable.
                var component:BaseComponent = ObjectFactory.CreateComponent("ScoreBoard", "getScores");
                component["id"] = 0;
                t.assertTrue(component.hasValidProperties(), "0 satisfies a required Number");
                t.done();
            });

            add("a session-gated component is invalid without a session", function(t:TestContext):void {
                // Medal.unlock sets requiresSession, so BaseComponent adds a session
                // check on top of the required-property check. With no core attached
                // there is no session to find.
                var component:BaseComponent = ObjectFactory.CreateComponent("Medal", "unlock");
                component["id"] = 1;

                t.assertFalse(component.hasValidProperties(), "no core means no session means invalid");
                t.assertEquals(0, component.getValidationErrors().length,
                    "the session rule is not reported by getValidationErrors()");
                t.done();
            });
        }

        //==================== HELPERS ====================

        private function countKeys(source:Object):int {
            var count:int = 0;
            for (var key:String in source) {
                count++;
            }
            return count;
        }
    }
}
