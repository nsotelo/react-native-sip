package com.reactnativesip

import android.util.Log
import com.facebook.react.bridge.*

import com.facebook.react.modules.core.DeviceEventManagerModule
import org.linphone.core.*


class SipModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  private val context = reactContext.applicationContext
  private val packageManager = context.packageManager
  private val reactContext = reactContext

  private var bluetoothMic: AudioDevice? = null
  private var bluetoothSpeaker: AudioDevice? = null
  private var earpiece: AudioDevice? = null
  private var loudMic: AudioDevice? = null
  private var loudSpeaker: AudioDevice? = null
  private var microphone: AudioDevice? = null

  private lateinit var core: Core

  companion object {
    const val TAG = "SipModule"
  }

  override fun getName(): String {
    return "Sip"
  }

  private fun delete() {
    // To completely remove an Account
    val account = core.defaultAccount
    account ?: return
    core.removeAccount(account)

    // To remove all accounts use
    core.clearAccounts()

    // Same for auth info
    core.clearAllAuthInfo()
  }

  private fun sendEvent(eventName: String) {
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
    .emit(eventName, null)
  }


  @ReactMethod
  fun addListener(eventName: String) {
    Log.d(TAG, "Added listener: $eventName")
  }

  @ReactMethod
  fun bluetoothAudio(promise: Promise) {
    if (bluetoothMic != null) {
      core.inputAudioDevice = bluetoothMic
    }

    if (bluetoothSpeaker != null) {
      core.outputAudioDevice = bluetoothSpeaker
    }

    promise.resolve(true)
  }

  @ReactMethod
  fun hangUp(promise: Promise) {
    Log.i(TAG, "Trying to hang up")
    if (core.callsNb == 0) return

    // If the call state isn't paused, we can get it using core.currentCall
    val call = if (core.currentCall != null) core.currentCall else core.calls[0]
    if (call != null) {
      // Terminating a call is quite simple
      call.terminate()
      promise.resolve(null)
    } else {
      promise.reject("No call", "No call to terminate")
    }
  }

  @ReactMethod
  fun initialise(promise: Promise) {
    val factory = Factory.instance()
    factory.setDebugMode(true, "Connected to linphone")
    core = factory.createCore(null, null, context)
    core.start()

    val coreListener = object : CoreListenerStub() {
      override fun onAudioDevicesListUpdated(core: Core) {
        sendEvent("AudioDevicesChanged")
      }

      override fun onCallStateChanged(
        core: Core,
        call: Call,
        state: Call.State?,
        message: String
      ) {
        when (state) {
          Call.State.IncomingReceived -> {
            // Immediately hang up when we receive a call. There's nothing inherently wrong with this
            // but we don't need it right now, so better to leave it deactivated.
            call.terminate()
          }
          Call.State.OutgoingInit -> {
            // First state an outgoing call will go through
            sendEvent("ConnectionRequested")
          }
          Call.State.OutgoingProgress -> {
            // First state an outgoing call will go through
            sendEvent("CallRequested")
          }
          Call.State.OutgoingRinging -> {
            // Once remote accepts, ringing will commence (180 response)
            sendEvent("CallRinging")
          }
          Call.State.Connected -> {
            sendEvent("CallConnected")
          }
          Call.State.StreamsRunning -> {
            // This state indicates the call is active.
            // You may reach this state multiple times, for example after a pause/resume
            // or after the ICE negotiation completes
            // Wait for the call to be connected before allowing a call update
            sendEvent("CallStreamsRunning")
          }
          Call.State.Paused -> {
            sendEvent("CallPaused")
          }
          Call.State.PausedByRemote -> {
            sendEvent("CallPausedByRemote")
          }
          Call.State.Updating -> {
            // When we request a call update, for example when toggling video
            sendEvent("CallUpdating")
          }
          Call.State.UpdatedByRemote -> {
            sendEvent("CallUpdatedByRemote")
          }
          Call.State.Released -> {
            sendEvent("CallReleased")
          }
          Call.State.Error -> {
            sendEvent("CallError")
          }
          else -> {
          }
        }
      }
    }

    core.addListener(coreListener)
    promise.resolve(null)
  }

  @ReactMethod
  fun login(username: String, password: String, domain: String, promise: Promise) {
    val transportType = TransportType.Tls

    // To configure a SIP account, we need an Account object and an AuthInfo object
    // The first one is how to connect to the proxy server, the second one stores the credentials

    // The auth info can be created from the Factory as it's only a data class
    // userID is set to null as it's the same as the username in our case
    // ha1 is set to null as we are using the clear text password. Upon first register, the hash will be computed automatically.
    // The realm will be determined automatically from the first register, as well as the algorithm
    val authInfo =
    Factory.instance().createAuthInfo(username, null, password, null, null, domain, null)

    // Account object replaces deprecated ProxyConfig object
    // Account object is configured through an AccountParams object that we can obtain from the Core
    val accountParams = core.createAccountParams()

    // A SIP account is identified by an identity address that we can construct from the username and domain
    val identity = Factory.instance().createAddress("sip:$username@$domain")
    accountParams.identityAddress = identity

    // We also need to configure where the proxy server is located
    val address = Factory.instance().createAddress("sip:$domain")
    // We use the Address object to easily set the transport protocol
    address?.transport = transportType
    accountParams.serverAddress = address
    // And we ensure the account will start the registration process
    accountParams.registerEnabled = true

    // Now that our AccountParams is configured, we can create the Account object
    val account = core.createAccount(accountParams)

    // Now let's add our objects to the Core
    core.addAuthInfo(authInfo)
    core.addAccount(account)

    // Also set the newly added account as default
    core.defaultAccount = account

    // We can also register a callback on the Account object
    account.addListener { _, state, message ->
      when (state) {
        RegistrationState.Ok -> {
          promise.resolve(true)
        }
        RegistrationState.Cleared -> {
          promise.resolve(false)
        }
        RegistrationState.Failed -> {
          promise.reject("Authentication error", message)
        }
        else -> {

        }
      }
    }
  }

  @ReactMethod
  fun loudAudio(promise: Promise) {
    if (loudMic != null) {
      core.inputAudioDevice = loudMic
    } else if (microphone != null) {
      core.inputAudioDevice = microphone
    }

    if (loudSpeaker != null) {
      core.outputAudioDevice = loudSpeaker
    }

    promise.resolve(true)
  }

  @ReactMethod
  fun micEnabled(promise: Promise) {
    promise.resolve(core.micEnabled())
  }

  @ReactMethod
  fun outgoingCall(recipient: String, promise: Promise) {
    // As for everything we need to get the SIP URI of the remote and convert it to an Address
    val remoteAddress = Factory.instance().createAddress(recipient)
    if (remoteAddress == null) {
      promise.reject("Invalid SIP URI", "Invalid SIP URI")
    } else {
      // We also need a CallParams object
      // Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
      val params = core.createCallParams(null)
      params ?: return // Same for params

      // We can now configure it
      // Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
      params.mediaEncryption = MediaEncryption.None
      // If we wanted to start the call with video directly
      //params.enableVideo(true)

      // Finally we start the call
      core.inviteAddressWithParams(remoteAddress, params)
      // Call process can be followed in onCallStateChanged callback from core listener

      promise.resolve(null)
    }

  }

  @ReactMethod
  fun phoneAudio(promise: Promise) {
    if (microphone != null) {
      core.inputAudioDevice = microphone
    }

    if (earpiece != null) {
      core.outputAudioDevice = earpiece
    }

    promise.resolve(true)
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    Log.d(TAG, "Removed $count listener(s)")
  }

  @ReactMethod
  fun scanAudioDevices(promise: Promise) {
    microphone = null
    earpiece = null
    loudSpeaker = null
    loudMic = null
    bluetoothSpeaker = null
    bluetoothMic = null

    for (audioDevice in core.audioDevices) {
      when (audioDevice.type) {
        AudioDevice.Type.Microphone -> microphone = audioDevice
        AudioDevice.Type.Earpiece -> earpiece = audioDevice
        AudioDevice.Type.Speaker -> if (audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)) {
          loudSpeaker = audioDevice
        } else {
          loudMic = audioDevice
        }
        AudioDevice.Type.Bluetooth -> if (audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)) {
          bluetoothSpeaker = audioDevice
        } else {
          bluetoothMic = audioDevice
        }
        else -> {
        }
      }
    }

    val options = Arguments.createMap()
    options.putBoolean("phone", earpiece != null && microphone != null)
    options.putBoolean("bluetooth", bluetoothMic != null || bluetoothSpeaker != null)
    options.putBoolean("loudspeaker", loudSpeaker != null)

    var current = "phone"
    if (core.outputAudioDevice?.type == AudioDevice.Type.Bluetooth || core.inputAudioDevice?.type == AudioDevice.Type.Bluetooth) {
      current = "bluetooth"
    } else if (core.outputAudioDevice?.type == AudioDevice.Type.Speaker) {
      current = "loudspeaker"
    }

    val result = Arguments.createMap()
    result.putString("current", current)
    result.putMap("options", options)
    promise.resolve(result)
  }

  @ReactMethod
  fun sendDtmf(dtmf: String, promise: Promise) {
    core.currentCall?.sendDtmf(dtmf.single())
    promise.resolve(true)
  }

  @ReactMethod
  fun toggleMute(promise: Promise) {
    val micEnabled = core.micEnabled()
    core.enableMic(!micEnabled)
    promise.resolve(!micEnabled)
  }

  @ReactMethod
  fun unregister(promise: Promise) {
    // Here we will disable the registration of our Account
    val account = core.defaultAccount
    account ?: return

    // Returned params object is const, so to make changes we first need to clone it
    val params = account.params.clone()

    params.registerEnabled = false
    account.params = params
    core.removeAccount(account)
    core.clearAllAuthInfo()

    promise.resolve(true)
  }
}
