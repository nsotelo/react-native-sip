import linphonesw
import React

@objc(Sip)
class Sip: RCTEventEmitter {
    private var mCore: Core!
    private var mRegistrationDelegate : CoreDelegate!
    
    private var bluetoothMic: AudioDevice?
    private var bluetoothSpeaker: AudioDevice?
    private var earpiece: AudioDevice?
    private var loudMic: AudioDevice?
    private var loudSpeaker: AudioDevice?
    private var microphone: AudioDevice?
    
    @objc func delete() {
        // To completely remove an Account
        if let account = mCore.defaultAccount {
            mCore.removeAccount(account: account)
            
            // To remove all accounts use
            mCore.clearAccounts()
            
            // Same for auth info
            mCore.clearAllAuthInfo()
        }}
    
    @objc func sendEvent( eventName: String ) {
        self.sendEvent(withName:eventName, body:"");
    }
    
    @objc(initialise:withRejecter:)
    func initialise(resolve:RCTPromiseResolveBlock,reject:RCTPromiseRejectBlock) {
        do {
            LoggingService.Instance.logLevel = LogLevel.Debug
            
            try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
            try? mCore.start()
            
            // Create a Core listener to listen for the callback we need
            // In this case, we want to know about the account registration status
            mRegistrationDelegate = CoreDelegateStub(
                onCallStateChanged: {(
                  core: Core,
                  call: Call,
                  state: Call.State?,
                  message: String
                ) in
                  switch (state) {
                  case .IncomingReceived:
                      // Immediately hang up when we receive a call. There's nothing inherently wrong with this
                      // but we don't need it right now, so better to leave it deactivated.
                      try! call.terminate()
                   case .OutgoingInit:
                      // First state an outgoing call will go through
                      self.sendEvent(eventName: "ConnectionRequested")
                case .OutgoingProgress:
                      // First state an outgoing call will go through
                      self.sendEvent(eventName: "CallRequested")
                  case .OutgoingRinging:
                      // Once remote accepts, ringing will commence (180 response)
                      self.sendEvent(eventName: "CallRinging")
                case .Connected:
                      self.sendEvent(eventName: "CallConnected")
                case .StreamsRunning:
                      // This state indicates the call is active.
                      // You may reach this state multiple times, for example after a pause/resume
                      // or after the ICE negotiation completes
                      // Wait for the call to be connected before allowing a call update
                      self.sendEvent(eventName: "CallStreamsRunning")
                case .Paused:
                      self.sendEvent(eventName: "CallPaused")
                case .PausedByRemote:
                      self.sendEvent(eventName: "CallPausedByRemote")
                  case .Updating:
                      // When we request a call update, for example when toggling video
                      self.sendEvent(eventName: "CallUpdating")
                  case .UpdatedByRemote:
                      self.sendEvent(eventName: "CallUpdatedByRemote")
                  case .Released:
                      self.sendEvent(eventName: "CallReleased")
                  case .Error:
                      self.sendEvent(eventName: "CallError")
                default:
                      NSLog("")
                  }
                },
                onAudioDevicesListUpdated: { (core: Core) in
                    self.sendEvent(eventName: "AudioDevicesChanged")
                })
            mCore.addDelegate(delegate: mRegistrationDelegate)
            resolve(true)
        }}
    
    @objc(login:withPassword:withDomain:withResolver:withRejecter:)
    func login(username: String, password: String, domain: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        do {
            let transport = TransportType.Tls
            
            // To configure a SIP account, we need an Account object and an AuthInfo object
            // The first one is how to connect to the proxy server, the second one stores the credentials
            
            // The auth info can be created from the Factory as it's only a data class
            // userID is set to null as it's the same as the username in our case
            // ha1 is set to null as we are using the clear text password. Upon first register, the hash will be computed automatically.
            // The realm will be determined automatically from the first register, as well as the algorithm
            let authInfo = try Factory.Instance.createAuthInfo(username: username, userid: "", passwd: password, ha1: "", realm: "", domain: domain)
            
            // Account object replaces deprecated ProxyConfig object
            // Account object is configured through an AccountParams object that we can obtain from the Core
            let accountParams = try mCore.createAccountParams()
            
            // A SIP account is identified by an identity address that we can construct from the username and domain
            let identity = try Factory.Instance.createAddress(addr: String("sip:" + username + "@" + domain))
            try! accountParams.setIdentityaddress(newValue: identity)
            
            // We also need to configure where the proxy server is located
            let address = try Factory.Instance.createAddress(addr: String("sip:" + domain))
            
            // We use the Address object to easily set the transport protocol
            try address.setTransport(newValue: transport)
            try accountParams.setServeraddress(newValue: address)
            // And we ensure the account will start the registration process
            accountParams.registerEnabled = true
            
            // Now that our AccountParams is configured, we can create the Account object
            let account = try mCore.createAccount(params: accountParams)
            
            // Now let's add our objects to the Core
            mCore.addAuthInfo(info: authInfo)
            try mCore.addAccount(account: account)
            
            // Also set the newly added account as default
            mCore.defaultAccount = account
            
            resolve(nil)
            
        } catch { NSLog(error.localizedDescription)
            reject("Login error", "Could not log in", error)
        }
    }
    
    @objc(bluetoothAudio:withRejecter:)
    func bluetoothAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        if let mic = self.bluetoothMic {
            mCore.inputAudioDevice = mic
        }
        
        if let speaker = self.bluetoothSpeaker {
            mCore.outputAudioDevice = speaker
        }
        
        resolve(true)
    }
    
    @objc
    override func supportedEvents() -> [String]! {
        return ["ConnectionRequested", "CallRequested", "CallRinging", "CallConnected", "CallStreamsRunning", "CallPaused", "CallPausedByRemote", "CallUpdating", "CallUpdatedByRemote", "CallReleased", "CallError", "AudioDevicesChanged"]
    }
    
    @objc(unregister:withRejecter:)
    func unregister(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock)
    {
        // Here we will disable the registration of our Account
        if let account = mCore.defaultAccount {
            
            let params = account.params
            // Returned params object is const, so to make changes we first need to clone it
            let clonedParams = params?.clone()
            
            // Now let's make our changes
            clonedParams?.registerEnabled = false
            
            // And apply them
            account.params = clonedParams
            mCore.removeAccount(account: account)
            mCore.clearAllAuthInfo()
        }
    }
    
    @objc(hangUp:withRejecter:)
    func hangUp(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        NSLog("Trying to hang up")
        do {
            if (mCore.callsNb == 0) { return }
            
            // If the call state isn't paused, we can get it using core.currentCall
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            // Terminating a call is quite simple
            if let call = coreCall {
                try call.terminate()
            } else {
                reject("No call", "No call to terminate", nil)
            }
        } catch {
            NSLog(error.localizedDescription)
            reject("Call termination failed", "Call termination failed", error)
            
        }
    }
    
    @objc(loudAudio:withRejecter:)
    func loudAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        if let mic = loudMic {
            mCore.inputAudioDevice = mic
        } else if let mic = self.microphone {
            mCore.inputAudioDevice = mic
        }
        
        if let speaker = loudSpeaker {
            mCore.outputAudioDevice = speaker
        }
        
        resolve(true)
    }
    
    @objc(micEnabled:withRejecter:)
    func micEnabled(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        resolve(mCore.micEnabled)
    }
    
    @objc(outgoingCall:withResolver:withRejecter:)
    func outgoingCall(recipient: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        do {
            // As for everything we need to get the SIP URI of the remote and convert it to an Address
            let remoteAddress = try Factory.Instance.createAddress(addr: recipient)
            
            // We also need a CallParams object
            // Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
            let params = try mCore.createCallParams(call: nil)
            
            // We can now configure it
            // Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
            params.mediaEncryption = MediaEncryption.None
            // If we wanted to start the call with video directly
            //params.videoEnabled = true
            
            // Finally we start the call
            let _ = mCore.inviteAddressWithParams(addr: remoteAddress, params: params)
            // Call process can be followed in onCallStateChanged callback from core listener
            resolve(nil)
        } catch { NSLog(error.localizedDescription)
            reject("Outgoing call failure", "Something has gone wrong", error)
        }
    }
    
    @objc(phoneAudio:withRejecter:)
    func phoneAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        if let mic = microphone {
            mCore.inputAudioDevice = mic
        }
        
        if let speaker = earpiece {
            mCore.outputAudioDevice = speaker
        }
        
        resolve(true)
    }
    
    @objc(scanAudioDevices:withRejecter:)
    func scanAudioDevices(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        microphone = nil
        earpiece = nil
        loudSpeaker = nil
        loudMic = nil
        bluetoothSpeaker = nil
        bluetoothMic = nil
        
        for audioDevice in mCore.audioDevices {
            switch (audioDevice.type) {
            case .Microphone:
                microphone = audioDevice
            case .Earpiece:
                earpiece = audioDevice
            case .Speaker:
                if (audioDevice.hasCapability(capability: AudioDeviceCapabilities.CapabilityPlay)) {
                    loudSpeaker = audioDevice
                } else {
                    loudMic = audioDevice
                }
            case .Bluetooth:
                if (audioDevice.hasCapability(capability: AudioDeviceCapabilities.CapabilityPlay)) {
                    bluetoothSpeaker = audioDevice
                } else {
                    bluetoothMic = audioDevice
                }
            default:
                NSLog("Audio device not recognised.")
            }
        }
        
        let options: NSDictionary = [
            "phone": earpiece != nil && microphone != nil,
            "bluetooth": bluetoothMic != nil || bluetoothSpeaker != nil,
            "loudspeaker": loudSpeaker != nil
        ]
        
        var current = "phone"
        if (mCore.outputAudioDevice?.type == .Bluetooth || mCore.inputAudioDevice?.type == .Bluetooth) {
            current = "bluetooth"
        } else if (mCore.outputAudioDevice?.type == .Speaker) {
            current = "loudspeaker"
        }
        
        let result: NSDictionary = [
            "current": current,
            "options": options
        ]
        resolve(result)
    }
    
    @objc(sendDtmf:withResolver:withRejecter:)
    func sendDtmf(dtmf: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        do {
            try mCore.currentCall?.sendDtmf(dtmf: dtmf.utf8CString[0])
            resolve(true) } catch {
                reject("DTMF not recognised", "DTMF not recognised", error)
            }
    }
    
    @objc(toggleMute:withRejecter:)
    func toggleMute(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        mCore.micEnabled = !mCore.micEnabled
        resolve(mCore.micEnabled)
    }
    
}
