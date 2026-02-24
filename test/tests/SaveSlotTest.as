package tests {
    import io.newgrounds.models.objects.SaveSlot;
    
    /**
     * Tests for SaveSlot-specific functionality
     */
    public class SaveSlotTest extends BaseTest {
        
        override public function runTests():Array {
            results = [];
            
            testSaveSlotCreation();
            testSaveSlotProperties();
            testSaveSlotSerialization();
            testSaveSlotDataHandling();
            
            return results;
        }
        
        private function testSaveSlotCreation():void {
            var saveSlot:SaveSlot = new SaveSlot();
            
            assertNotNull(saveSlot, "SaveSlot instance created");
            assertEquals("SaveSlot", saveSlot.objectName, "SaveSlot object name correct");
            assertEquals("object", saveSlot.objectType, "SaveSlot object type correct");
        }
        
        private function testSaveSlotProperties():void {
            var saveSlot:SaveSlot = new SaveSlot();
            saveSlot.id = 1;
            saveSlot.size = 1024;
            saveSlot.timestamp = 1234567890;
            
            assertEquals(1, saveSlot.id, "SaveSlot ID set correctly");
            assertEquals(1024, saveSlot.size, "SaveSlot size set correctly");
            assertEquals(1234567890, saveSlot.timestamp, "SaveSlot timestamp set correctly");
        }
        
        private function testSaveSlotSerialization():void {
            var data:Object = {
                id: 5,
                size: 2048,
                timestamp: 9876543210
            };
            
            var saveSlot:SaveSlot = new SaveSlot();
            saveSlot.importFromObject(data);
            
            assertEquals(5, saveSlot.id, "SaveSlot ID deserialized");
            assertEquals(2048, saveSlot.size, "SaveSlot size deserialized");
            assertEquals(9876543210, saveSlot.timestamp, "SaveSlot timestamp deserialized");
        }
        
        private function testSaveSlotDataHandling():void {
            var saveSlot:SaveSlot = new SaveSlot();
            var json:Object = saveSlot.toJSON();
            
            assertNotNull(json, "SaveSlot toJSON returns object");
            assertEquals("SaveSlot", saveSlot.objectName, "SaveSlot object name property correct");
        }
    }
}
