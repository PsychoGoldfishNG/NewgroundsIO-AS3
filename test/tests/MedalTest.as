package tests {
    import io.newgrounds.models.objects.Medal;
    
    /**
     * Tests for Medal-specific functionality
     */
    public class MedalTest extends BaseTest {
        
        override public function runTests():Array {
            results = [];
            
            testMedalCreation();
            testMedalProperties();
            testClearSessionData();
            
            return results;
        }
        
        private function testMedalCreation():void {
            var medal:Medal = new Medal();
            
            assertNotNull(medal, "Medal instance created");
            assertEquals("Medal", medal.objectName, "Medal object name correct");
            assertEquals("object", medal.objectType, "Medal object type correct");
        }
        
        private function testMedalProperties():void {
            var medal:Medal = new Medal();
            medal.id = 123;
            medal.name = "Test Achievement";
            medal.value = 25;
            medal.difficulty = 2;
            medal.secret = true;
            medal.unlocked = false;
            
            assertEquals(123, medal.id, "Medal ID set correctly");
            assertEquals("Test Achievement", medal.name, "Medal name set correctly");
            assertEquals(25, medal.value, "Medal value set correctly");
            assertEquals(2, medal.difficulty, "Medal difficulty set correctly");
            assertTrue(medal.secret, "Medal secret flag set correctly");
            assertFalse(medal.unlocked, "Medal unlocked flag set correctly");
        }
        
        private function testClearSessionData():void {
            var medal:Medal = new Medal();
            medal.unlocked = true;
            
            medal.clearSessionData();
            
            assertFalse(medal.unlocked, "Unlocked flag reset after clearSessionData");
        }
    }
}
