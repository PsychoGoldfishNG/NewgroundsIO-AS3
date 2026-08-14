/**
 * OfflineObjectFactorySuite
 *
 * ObjectFactory is a hand-maintained switch over every model name in the
 * library. A model that gets added to the codebase but not to the switch fails
 * silently at runtime - CreateObject just returns null and the caller stores
 * nothing. These tests walk the full expected inventory so that gap shows up
 * here instead of as a mysteriously empty medal list.
 */
package ngiotest.suites {

    import io.newgrounds.BaseComponent;
    import io.newgrounds.BaseObject;
    import io.newgrounds.BaseResult;
    import io.newgrounds.Core;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.NgioError;
    import io.newgrounds.models.objects.ObjectFactory;
    import io.newgrounds.models.objects.User;

    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineObjectFactorySuite extends TestSuite {

        /** Every object model the factory is expected to know about */
        private static const OBJECT_NAMES:Array = [
            "Request", "Execute", "Debug", "Response", "Error",
            "Session", "User", "Medal", "ScoreBoard", "Score", "SaveSlot"
        ];

        /**
         * Every component the gateway exposes, as "Component.method".
         * Results are expected to exist for exactly the same list.
         */
        private static const COMPONENT_PATHS:Array = [
            "App.logView", "App.checkSession", "App.getHostLicense",
            "App.getCurrentVersion", "App.startSession", "App.endSession",
            "CloudSave.clearSlot", "CloudSave.loadSlot", "CloudSave.loadSlots", "CloudSave.setData",
            "Event.logEvent",
            "Gateway.getVersion", "Gateway.getDatetime", "Gateway.ping",
            "Loader.loadOfficialUrl", "Loader.loadAuthorUrl", "Loader.loadReferral",
            "Loader.loadMoreGames", "Loader.loadNewgrounds",
            "Medal.getList", "Medal.getMedalScore", "Medal.unlock",
            "ScoreBoard.getBoards", "ScoreBoard.postScore", "ScoreBoard.getScores"
        ];

        override public function get suiteName():String {
            return "Offline / ObjectFactory";
        }

        override public function build():void {

            add("creates every registered object model", function(t:TestContext):void {
                for each (var name:String in OBJECT_NAMES) {
                    var model:BaseObject = ObjectFactory.CreateObject(name);
                    if (t.assertNotNull(model, "CreateObject('" + name + "')")) {
                        t.assertEquals("object", model.objectType, name + " reports objectType 'object'");
                    }
                }
                t.done();
            });

            add("creates every registered component", function(t:TestContext):void {
                for each (var path:String in COMPONENT_PATHS) {
                    var parts:Array = path.split(".");
                    var component:BaseComponent = ObjectFactory.CreateComponent(parts[0], parts[1]);

                    if (t.assertNotNull(component, "CreateComponent('" + path + "')")) {
                        t.assertEquals(path, component.objectName, path + " reports its own name");
                        t.assertEquals("component", component.objectType, path + " reports objectType 'component'");
                    }
                }
                t.done();
            });

            add("creates every registered result", function(t:TestContext):void {
                for each (var path:String in COMPONENT_PATHS) {
                    var parts:Array = path.split(".");
                    var result:BaseResult = ObjectFactory.CreateResult(parts[0], parts[1]);

                    if (t.assertNotNull(result, "CreateResult('" + path + "')")) {
                        t.assertEquals(path, result.objectName, path + " result reports its own name");
                        t.assertEquals("result", result.objectType, path + " reports objectType 'result'");
                    }
                }
                t.done();
            });

            add("matches names case-insensitively", function(t:TestContext):void {
                t.assertIsType(ObjectFactory.CreateObject("medal"), Medal, "lowercase");
                t.assertIsType(ObjectFactory.CreateObject("MEDAL"), Medal, "uppercase");
                t.assertIsType(ObjectFactory.CreateObject("Medal"), Medal, "PascalCase");
                t.assertIsType(ObjectFactory.CreateObject("mEdAl"), Medal, "mixed case");

                t.assertNotNull(ObjectFactory.CreateComponent("MEDAL", "UNLOCK"), "component, uppercase");
                t.assertNotNull(ObjectFactory.CreateResult("medal", "unlock"), "result, lowercase");
                t.done();
            });

            add("maps the name 'Error' to NgioError", function(t:TestContext):void {
                // The schema calls it Error; the class is renamed because Error is
                // a reserved top-level type in AS3. That rename is only safe if the
                // factory still answers to the schema name.
                var error:BaseObject = ObjectFactory.CreateObject("Error");
                t.assertIsType(error, NgioError, "CreateObject('Error') builds an NgioError");
                t.assertEquals("Error", error.objectName, "and still calls itself Error");
                t.done();
            });

            add("returns null for unknown names", function(t:TestContext):void {
                t.assertNull(ObjectFactory.CreateObject("NoSuchObject"), "unknown object");
                t.assertNull(ObjectFactory.CreateComponent("NoSuch", "method"), "unknown component");
                t.assertNull(ObjectFactory.CreateResult("NoSuch", "method"), "unknown result");

                // BaseObject.importFromObject() asks the factory for its own
                // objectName, which for a component is dotted ("Medal.unlock") and
                // deliberately absent from CreateObject's switch. Returning null
                // rather than throwing is what keeps that path working.
                t.assertNull(ObjectFactory.CreateObject("Medal.unlock"), "dotted component name");
                t.done();
            });

            add("returns null for empty names", function(t:TestContext):void {
                t.assertNull(ObjectFactory.CreateObject(null), "null object name");
                t.assertNull(ObjectFactory.CreateObject(""), "empty object name");
                t.assertNull(ObjectFactory.CreateComponent(null, "unlock"), "null component");
                t.assertNull(ObjectFactory.CreateComponent("Medal", null), "null method");
                t.assertNull(ObjectFactory.CreateComponent("Medal", ""), "empty method");
                t.done();
            });

            add("attaches the supplied Core reference", function(t:TestContext):void {
                var core:Core = new Core("unit-test:offline", TestConfigKey());

                var model:BaseObject = ObjectFactory.CreateObject("Medal", null, core);
                t.assertStrictEquals(core, model.core, "object got the core");

                var component:BaseComponent = ObjectFactory.CreateComponent("Medal", "unlock", null, core);
                t.assertStrictEquals(core, component.core, "component got the core");

                var result:BaseResult = ObjectFactory.CreateResult("Medal", "unlock", null, core);
                t.assertStrictEquals(core, result.core, "result got the core");
                t.done();
            });

            add("imports supplied data on creation", function(t:TestContext):void {
                var medal:Medal = ObjectFactory.CreateObject("Medal", { id: 8, name: "Factory" }) as Medal;
                if (t.assertNotNull(medal, "medal created")) {
                    t.assertEquals(8, medal.id, "id imported");
                    t.assertEquals("Factory", medal.name, "name imported");
                }

                var component:BaseComponent = ObjectFactory.CreateComponent("Medal", "unlock", { id: 99 });
                if (t.assertNotNull(component, "component created")) {
                    t.assertEquals(99, component["id"], "component parameter imported");
                }

                var user:User = ObjectFactory.CreateObject("User", { id: 3, name: "Imported" }) as User;
                if (t.assertNotNull(user, "user created")) {
                    t.assertEquals("Imported", user.name, "user name imported");
                }
                t.done();
            });

            add("returns a distinct instance every call", function(t:TestContext):void {
                var first:Medal = ObjectFactory.CreateObject("Medal") as Medal;
                var second:Medal = ObjectFactory.CreateObject("Medal") as Medal;

                first.id = 1;
                second.id = 2;

                t.assertNotEquals(first, second, "instances are not the same object");
                t.assertEquals(1, first.id, "first kept its own state");
                t.assertEquals(2, second.id, "second kept its own state");
                t.done();
            });
        }

        /**
         * A syntactically valid Base64 AES key for constructing throwaway Core
         * instances. Never sent anywhere - these tests make no network calls.
         */
        private function TestConfigKey():String {
            return "AAECAwQFBgcICQoLDA0ODw==";
        }
    }
}
