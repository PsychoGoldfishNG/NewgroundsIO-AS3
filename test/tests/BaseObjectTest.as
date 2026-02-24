package tests {
    import io.newgrounds.BaseObject;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.User;
    
    /**
     * Tests for BaseObject serialization/deserialization
     */
    public class BaseObjectTest extends BaseTest {
        
        override public function runTests():Array {
            results = [];
            
            testMedalDeserialization();
            testMedalSerialization();
            testUserDeserialization();
            testPropertyValidation();
            testTypeCasting();
            
            return results;
        }
        
        private function testMedalDeserialization():void {
            var data:Object = {
                id: 12345,
                name: "Test Medal",
                description: "A test medal",
                icon: "http://example.com/icon.png",
                value: 50,
                difficulty: 3,
                secret: false,
                unlocked: true
            };
            
            var medal:Medal = new Medal();
            medal.importFromObject(data);
            
            assertEquals(12345, medal.id, "Medal ID deserialized");
            assertEquals("Test Medal", medal.name, "Medal name deserialized");
            assertEquals(50, medal.value, "Medal value deserialized");
            assertTrue(medal.unlocked, "Medal unlocked flag deserialized");
        }
        
        private function testMedalSerialization():void {
            var medal:Medal = new Medal();
            medal.id = 999;
            medal.name = "Serialization Test";
            medal.value = 100;
            medal.unlocked = false;
            
            var json:Object = medal.toJSON();
            
            assertEquals(999, json.id, "Medal ID serialized");
            assertEquals("Serialization Test", json.name, "Medal name serialized");
            assertEquals(100, json.value, "Medal value serialized");
            assertFalse(json.unlocked, "Medal unlocked flag serialized");
        }
        
        private function testUserDeserialization():void {
            var data:Object = {
                id: 54321,
                name: "TestUser",
                supporter: true
            };
            
            var user:User = new User();
            user.importFromObject(data);
            
            assertEquals(54321, user.id, "User ID deserialized");
            assertEquals("TestUser", user.name, "User name deserialized");
            assertTrue(user.supporter, "User supporter flag deserialized");
        }
        
        private function testPropertyValidation():void {
            var medal:Medal = new Medal();
            var propertyNames:Array = medal.propertyNames;
            
            assert(propertyNames.length > 0, "Medal has property names");
            assert(propertyNames.indexOf("id") >= 0, "Medal properties include 'id'");
            assert(propertyNames.indexOf("name") >= 0, "Medal properties include 'name'");
        }
        
        private function testTypeCasting():void {
            var medal:Medal = new Medal();
            var castTypes:Object = medal.castTypes;
            
            assertNotNull(castTypes, "Cast types object exists");
            assertEquals("object", medal.objectType, "Medal object type is 'object'");
            assertEquals("Medal", medal.objectName, "Medal object name is 'Medal'");
        }
    }
}
