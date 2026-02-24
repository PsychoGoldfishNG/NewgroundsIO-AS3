/**
 * Core
 * 
 * Handles core API communication, encryption, and app state management
 * 
 * This class is the heart of the Newgrounds.io library. It handles:
 * - Network communication with the Newgrounds servers
 * - Encrypting secure components to prevent cheating
 * - Managing a queue of components to send in batch requests
 * - Parsing server responses and updating the app state
 * 
 * WHY SEPARATE?: Developers should use the NGIO wrapper for simple tasks, but advanced users
 * can access Core directly for more control (via NGIO.core).
 */
package io.newgrounds {
	
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	import flash.system.Security;
	
	import com.hurlant.crypto.Crypto;
	import com.hurlant.crypto.prng.Random;
	import com.hurlant.crypto.symmetric.ICipher;
	import com.hurlant.crypto.symmetric.IPad;
	import com.hurlant.crypto.symmetric.PKCS5;
	import com.hurlant.util.Base64;
	
	import io.newgrounds.models.objects.Session;
	import io.newgrounds.models.objects.ObjectFactory;
	import io.newgrounds.helpers.CoreComponentCallHelper;
	import io.newgrounds.helpers.CoreQueueExecutionHelper;
	import io.newgrounds.helpers.HttpRequestHelper;
	import io.newgrounds.helpers.HttpResponseHelper;
	import io.newgrounds.helpers.CoreTransportHelper;
	
	public class Core {
		
		//==================== CONSTANTS ====================
		
		/**
		 * The server endpoint where all API calls are sent
		 * All requests go to this single URL on the Newgrounds servers
		 */
		public static const GATEWAY_URL:String = "https://www.newgrounds.io/gateway_v3.php";
		
		/**
		 * The crossdomain.xml policy file URL for Flash socket policy
		 * This allows Flash to make HTTPS connections to Newgrounds servers
		 */
		public static const POLICY_FILE_URL:String = "https://www.newgrounds.io/crossdomain.xml";
		
		/**
		 * Maximum number of components that can be bundled in a single request
		 * The server has limits to prevent abuse
		 */
		public static const MAX_QUEUE_SIZE:int = 10;
		
        //==================== PUBLIC PROPERTIES ====================
        
        /**
         * Set to true to show packets going to and from the server
         */
        public var debugNetworkCalls:Boolean = false;

		//==================== READONLY PROPERTIES ====================
		
		/**
		 * Stores the app ID provided at initialization
		 * Every request needs the app ID so the server knows which app is making the request
		 */
		public var appId:String;
		
		/**
		 * Stores the app's version number provided at initialization
		 * Used to check if the app is outdated and notify the user to update
		 */
		public var buildVersion:String = null;
		
		/**
		 * Stores cached data loaded from the server (medals, scoreboards, etc.)
		 * Instead of contacting the server repeatedly, we cache the data locally for fast access
		 */
		public var appState:AppState;
		
		//==================== PRIVATE PROPERTIES ====================
		
		/**
		 * Stores the encryption key used to encrypt secure components (decoded from Base64)
		 * The library encrypts certain components (like medal unlocks) to prevent cheating
		 */
		private var encryptionKeyBytes:ByteArray;
		
		/**
		 * Temporary storage for components waiting to be sent to the server
		 * Instead of sending each component immediately, we batch them together for efficiency
		 */
		private var componentQueue:Array = [];
		
		//==================== PUBLIC PROPERTIES ====================
		
		/**
		 * If true, API calls don't actually save to the server
		 * Useful for testing - you can unlock medals, post scores, etc. without affecting
		 * the actual game data
		 */
		public var useDebugMode:Boolean = false;
		
		//==================== CONSTRUCTOR ====================
		
		/**
		 * Initialize the Core object with the settings needed to communicate with the server
		 * 
		 * @param appId The unique identifier for the app (from Newgrounds)
		 * @param encryptionKey The key used for encryption (from Newgrounds)
		 * @param buildVersion The app's version number in XX.XX.XXXX format (optional)
		 * @param useDebugMode Whether to run in test mode (optional, default: false)
		 */
		public function Core(appId:String, encryptionKey:String, buildVersion:String = null, useDebugMode:Boolean = false) {
			// Store all the configuration values we'll need
			this.appId = appId;
			// Decode Base64 encryption key once and store as bytes
			if (encryptionKey == null || encryptionKey.length == 0) {
				trace("Encryption Error: Missing Base64 encryption key");
				this.encryptionKeyBytes = new ByteArray();
			} else {
				try {
					this.encryptionKeyBytes = Base64.decodeToByteArray(encryptionKey);
				} catch (e:*) {
					trace("Encryption Error: Invalid Base64 encryption key - " + e);
					this.encryptionKeyBytes = new ByteArray();
				}
			}
			this.buildVersion = buildVersion;
			this.useDebugMode = useDebugMode;
			
			// Create an empty queue for components
			// This will be filled by queueComponent() and sent by executeQueue()
			this.componentQueue = [];
			
			// Create a new AppState instance
			this.appState = new AppState(this);
			
			// Load the crossdomain policy file to allow HTTPS connections
			// This must be done before making any HTTPS requests
			Security.loadPolicyFile(POLICY_FILE_URL);
		}
		
		//==================== PUBLIC METHODS ====================
		
		/**
		 * Check if the user has an active session
		 * @return true if there's an active session with a valid session ID
		 */
		public function hasSession():Boolean {
			return (appState != null && 
					appState.session != null && 
					appState.session.id != null && 
					appState.session.id.length > 0);
		}
		
		/**
		 * Get or set the session ID
		 * @return The current session ID, or null if no session exists
		 */
		public function get sessionId():String {
			if (appState != null && appState.session != null) {
				return appState.session.id;
			}
			return null;
		}
		
		public function set sessionId(value:String):void {
			if (appState != null) {
				if (appState.session == null) {
					// Create a new session if needed
					appState.session = new Session();
				}
				appState.session.id = value;
			}
		}
		
		/**
		 * Convenience method to call a component directly with parameters
		 * This handles creating the component, executing it, and managing callbacks
		 * 
		 * @param componentPath The component to call (e.g. "Medal.unlock")
		 * @param componentParams Parameters for the component
		 * @param callback Function to call with the result
		 * @param thisArg Context for the callback
		 * @param callbackParams Additional parameters to pass to callback
		 */
		public function callComponent(componentPath:String, componentParams:Object = null, callback:Function = null, thisArg:* = null, callbackParams:Object = null):void {
			CoreComponentCallHelper.callComponent(this, componentPath, componentParams, callback, thisArg, callbackParams);
		}
		
		/**
		 * Add a component to the queue of components to send
		 * Queuing lets us send multiple components in one network request for efficiency
		 * 
		 * @param componentModel A component instance (like Medal.unlock) ready to send
		 */
		public function queueComponent(componentModel:BaseComponent):void {
			// Check that the queue isn't full
			// If it is, sending it would exceed the server's limits
			if (componentQueue.length < MAX_QUEUE_SIZE) {
				// Wrap the component in an Execute object for transmission
				var executeModel:io.newgrounds.models.objects.Execute = ObjectFactory.CreateObject("Execute", null, this) as io.newgrounds.models.objects.Execute;
				executeModel.setComponent(componentModel);
				
				// Add to queue
				componentQueue.push(executeModel);
			} else {
				// Queue is full - this is a developer error
				throw new Error("Component queue limit exceeded");
			}
		}
		
		/**
		 * Send all queued components to the server in a single request
		 * Batching requests improves performance and reduces server load
		 * Note: Components are already wrapped in Execute objects by queueComponent()
		 * 
		 * @param callback Function called with (resultModel) when server replies
		 */
		public function executeQueue(callback:Function = null, thisArg:* = null):void {
			// If queue is empty, nothing to do
			if (componentQueue.length == 0) {
				if (callback != null) {
					callback.call(thisArg, null);
				}
				return;
			}
			
			var partitionedQueue:Object = CoreQueueExecutionHelper.partitionExecuteQueue(componentQueue, this);
			var redirectComponents:Array = partitionedQueue.redirectComponents;
			var toExecute:Array = partitionedQueue.batchedExecuteWrappers;
			
			for each (var redirectComponent:BaseComponent in redirectComponents) {
				executeComponent(redirectComponent, callback, thisArg);
			}
			
			// Queue has been processed - clear it for next batch
			componentQueue = [];
			
			// If we ended up with no components to send, we're done
			if (toExecute.length == 0) {
				if (callback != null) {
					callback.call(thisArg, null);
				}
				return;
			}
			
			// Send all the components to the server
			sendRequest(toExecute, false, callback, thisArg);
		}
		
		/**
		 * Execute a single component immediately (not queued)
		 * Some components need immediate execution, not batching
		 * 
		 * @param componentModel The component to execute
		 * @param callback Function called with (resultModel) when server replies
		 */
		public function executeComponent(componentModel:BaseComponent, callback:Function = null, thisArg:* = null):void {
			// Set core reference on component if not already set
			if (componentModel != null && componentModel.core == null) {
				componentModel.core = this;
			}
			
			// Wrap the component for transmission
			var executeModel:io.newgrounds.models.objects.Execute = ObjectFactory.CreateObject("Execute", null, this) as io.newgrounds.models.objects.Execute;
			executeModel.core = this;
			executeModel.setComponent(componentModel);
			
			// Get redirect flag from the component
			var isRedirect:Boolean = componentModel.redirect;
			// Send it with the redirect flag from the component
			sendRequest(executeModel, isRedirect, callback, thisArg);
		}
		
		/**
		 * Encrypts a plain object to obfuscate secure components
		 * Makes cheating harder - medal unlocks and score posts are encrypted
		 * 
		 * IMPLEMENTATION: Uses as3crypto library (com.hurlant.crypto.*)
		 * - Algorithm: AES-128-CBC (Advanced Encryption Standard, 128-bit key, Cipher Block Chaining mode)
		 * - Padding: PKCS5 (standard padding for block ciphers)
		 * - Output: Base64-encoded ciphertext with prepended IV
		 * 
		 * @param obj The plain object to encrypt (usually a JSON-compatible object)
		 * @return The encrypted data encoded as Base64 string
		 */
		public function encryptObject(obj:Object):String {

            try {
                // Convert the object to a JSON string
                var jsonString:String = NGJSON.stringify(obj);
            }
            catch(e:*) {
                trace("Encryption Error: Failed to convert object to JSON - " + e);
                return null;
            }

            try {
                // Encrypt the JSON string using the encryption key
                var encryptedString:String = encryptData(jsonString);
            }
            catch(e:*) {
                trace("Encryption Error: Failed to encrypt JSON string - " + e);
                return null;
            }

            return encryptedString;
        }

		/**
		 * Encrypts text (usually JSON) to obfuscate secure components
		 * Makes cheating harder - medal unlocks and score posts are encrypted
		 * 
		 * IMPLEMENTATION: Uses as3crypto library (com.hurlant.crypto.*)
		 * - Algorithm: AES-128-CBC (Advanced Encryption Standard, 128-bit key, Cipher Block Chaining mode)
		 * - Padding: PKCS5 (standard padding for block ciphers)
		 * - Output: Base64-encoded ciphertext with prepended IV
		 * 
		 * @param text The data to encrypt (usually a JSON string)
		 * @return The encrypted data encoded as Base64 string
		 */
		public function encryptData(text:String):String {
			// Use the cached Base64-decoded encryption key bytes
			if (this.encryptionKeyBytes == null || this.encryptionKeyBytes.length == 0) {
				trace("Encryption Error: Encryption key bytes not set");
				return null;
			}
			var keyBytes:ByteArray = new ByteArray();
			keyBytes.writeBytes(this.encryptionKeyBytes);
			keyBytes.position = 0;
			
			// Create AES-128-CBC cipher using as3crypto
			// 'simple-aes-cbc' mode automatically handles IV (prepends it to ciphertext)
			var cipher:ICipher = Crypto.getCipher("simple-aes-cbc", keyBytes, new PKCS5());
			
			// Convert the input text to ByteArray
			var inputBytes:ByteArray = new ByteArray();
			inputBytes.writeUTFBytes(text);
			
			// Encrypt the data
			// The cipher modifies the ByteArray in-place
			cipher.encrypt(inputBytes);
			
			// Reset position for reading
			inputBytes.position = 0;
			
			// Encode encrypted bytes as Base64 string for transmission
			var encryptedBase64:String = Base64.encodeByteArray(inputBytes);
			
			return encryptedBase64;
		}
		
		//==================== PRIVATE METHODS ====================
		
		/**
		 * The core network communication method. Handles all server communication
		 * 
		 * This method does several things:
		 * 1. Wraps all components in a Request object
		 * 2. Serializes Request/Execute via HttpRequestHelper
		 * 3. Routes transport via CoreTransportHelper (browser redirect or HTTP)
		 * 4. Forwards transport callbacks into onHTTPResponse
		 * 5. Calls callback with normalized Response model
		 * 
		 * @param toExecute One or more Execute objects wrapping components
		 * @param openInBrowser If true, open in browser window instead of making AJAX request
		 * @param callback Function called with (resultModel) when server replies
		 */
		private function sendRequest(toExecute:*, openInBrowser:Boolean, callback:Function = null, thisArg:* = null):void {
			// ==================== PREPARE THE REQUEST ====================
			// Request/Execute are container models. Complex gateway formatting
			// (including secure Execute encryption) is centralized in HttpRequestHelper.
			// Create a proper Request object using ObjectFactory
			var requestModel:io.newgrounds.models.objects.Request = ObjectFactory.CreateObject("Request", null, this) as io.newgrounds.models.objects.Request;
			
			requestModel.core = this;
			requestModel.app_id = this.appId;
			requestModel.debug = this.useDebugMode;
			
			// Add session ID if available
			if (this.appState != null && this.appState.session != null && this.appState.session.id != null) {
				requestModel.session_id = this.appState.session.id;
			}
			
			// Add components to the request using mixed-type handling
			if (toExecute != null) {
				// Handle both single Execute object and array of Execute objects
				if (toExecute is Array) {
					// Array of Execute objects
					if (toExecute.length > 0) {
						requestModel.setExecuteList(toExecute);
					}
				} else {
					// Single Execute object
					requestModel.setExecute(toExecute);
				}
			}
			
			// Convert Request/Execute container models to API transmission format
			var plainObject:Object = HttpRequestHelper.buildGatewayRequestObject(requestModel);
			// Encode as JSON string for transmission
			var requestString:String = NGJSON.stringify(plainObject);
			
			// ==================== SEND THE REQUEST ====================
			
			// Loader components go to browser; all others use URLLoader HTTP transport.
			if (openInBrowser) {
				CoreTransportHelper.sendBrowserRequest(this, requestString, toExecute, callback, thisArg);
				return;
			}
			
			CoreTransportHelper.sendHttpRequest(this, requestString, callback, thisArg);
		}
		
		/**
		 * Internal forwarding entry for transport helper event callbacks.
		 */
		public function forwardHTTPResponse(statusCode:int, responseText:String, callback:Function, thisArg:* = null):void {
			onHTTPResponse(statusCode, responseText, callback, thisArg);
		}
		
		/**
		 * Handle HTTP response from the server
		 * 
		 * @param statusCode HTTP status code (200 = success, 4xx/5xx = error)
		 * @param responseText Response body from server
		 * @param callback Developer's callback function
		 */
		private function onHTTPResponse(statusCode:int, responseText:String, callback:Function, thisArg:* = null):void {
			
			// Create a Response object to hold all the results
			var responseModel:io.newgrounds.models.objects.Response = ObjectFactory.CreateObject("Response", null, this) as io.newgrounds.models.objects.Response;

			// Check HTTP status code
			// 200-299 = success, anything else = error
			if (statusCode < 200 || statusCode > 299) {
				// HTTP error - create error model
				responseModel.error = Errors.getError(statusCode);
			} else {
				// HTTP succeeded - parse the response JSON
				try {
					var jsonObject:Object = NGJSON.parse(responseText);
				} catch (error:*) {
					// JSON parsing failed - create appropriate error
                    trace("JSON parsing error - " + error.message);

                    responseModel.error = Errors.getError(
                        Errors.INVALID_REQUEST,
                        "Unable to parse JSON response"
                    );

                    jsonObject = null;
				}

				if (jsonObject != null) {
					try {
						HttpResponseHelper.importResponseObject(responseModel, jsonObject);
					} catch (importError:*) {
						trace("IMPORT ERROR: Error importing into Response model with object: " + NGJSON.stringify(jsonObject) + " :: " + importError.message);

						responseModel.error = Errors.getError(
							Errors.INVALID_RESPONSE,
							"Error importing response data"
						);
					}
				}
			}
			
			// Call the callback to return results to the developer
			if (callback != null) {
				callback.call(thisArg, responseModel);
			}
		}
	}
}
