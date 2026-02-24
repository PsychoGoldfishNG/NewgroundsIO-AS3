package tests {
    import io.newgrounds.models.objects.ObjectFactory;
    import io.newgrounds.BaseObject;
    import io.newgrounds.BaseComponent;
    import io.newgrounds.BaseResult;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.User;
    
    /**
     * Tests for ObjectFactory
     */
    public class ObjectFactoryTest extends BaseTest {
        
        override public function runTests():Array {
            results = [];
            
            testCreateObject();
            testCreateComponent();
            testCreateResult();
            testCaseInsensitivity();
            testInvalidNames();
            
            return results;
        }
        
        private function testCreateObject():void {
            var medal:BaseObject = ObjectFactory.CreateObject("Medal");
            
            assertNotNull(medal, "CreateObject returns Medal instance");
            assert(medal is Medal, "Returned object is Medal type");
            assertEquals("Medal", medal.objectName, "Medal object name correct");
            
            var user:BaseObject = ObjectFactory.CreateObject("User");
            assertNotNull(user, "CreateObject returns User instance");
            assert(user is User, "Returned object is User type");
        }
        
        private function testCreateComponent():void {
            var component:BaseComponent = ObjectFactory.CreateComponent("Medal", "unlock");
            
            assertNotNull(component, "CreateComponent returns component");
            assertEquals("Medal.unlock", component.objectName, "Component name correct");
            assertEquals("component", component.objectType, "Component type correct");
        }
        
        private function testCreateResult():void {
            var result:BaseResult = ObjectFactory.CreateResult("Medal", "unlock");
            
            assertNotNull(result, "CreateResult returns result");
            assertEquals("Medal.unlock", result.objectName, "Result name correct");
            assertEquals("result", result.objectType, "Result type correct");
        }
        
        private function testCaseInsensitivity():void {
            var medal1:BaseObject = ObjectFactory.CreateObject("medal");
            var medal2:BaseObject = ObjectFactory.CreateObject("MEDAL");
            var medal3:BaseObject = ObjectFactory.CreateObject("Medal");
            
            assertNotNull(medal1, "CreateObject works with lowercase");
            assertNotNull(medal2, "CreateObject works with uppercase");
            assertNotNull(medal3, "CreateObject works with PascalCase");
            
            assert(medal1 is Medal, "All return Medal type");
            assert(medal2 is Medal, "All return Medal type");
            assert(medal3 is Medal, "All return Medal type");
        }
        
        private function testInvalidNames():void {
            var obj:BaseObject = ObjectFactory.CreateObject("InvalidObject");
            assertNull(obj, "CreateObject returns null for invalid name");
            
            var comp:BaseComponent = ObjectFactory.CreateComponent("Invalid", "method");
            assertNull(comp, "CreateComponent returns null for invalid name");
            
            var result:BaseResult = ObjectFactory.CreateResult("Invalid", "method");
            assertNull(result, "CreateResult returns null for invalid name");
        }
    }
}
