import { NativeModules, Platform } from 'react-native'
import { NativeEventEmitter } from 'react-native'
import React from 'react'

const LINKING_ERROR =
  `The package 'react-native-sip' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n'

export const Sip = NativeModules.Sip
  ? NativeModules.Sip
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR)
        },
      }
    )

interface Callbacks {
  // First state an outgoing call will go through
  onConnectionRequested?: () => void

  // First state an outgoing call will go through
  onCallRequested?: () => void

  // Once remote accepts, ringing will commence (180 response)
  onCallRinging?: () => void
  onCallConnected?: () => void

  // This state indicates the call is active.
  // You may reach this state multiple times, for example after a pause/resume
  // or after the ICE negotiation completes
  // Wait for the call to be connected before allowing a call update
  onCallStreamsRunning?: () => void
  onCallPaused?: () => void
  onCallPausedByRemote?: () => void

  // When we request a call update, for example when toggling video
  onCallUpdating?: () => void
  onCallUpdatedByRemote?: () => void
  onCallReleased?: () => void
  onCallError?: () => void
  onLogin?: (username?: string) => void
  onLogout?: (username: string) => void
  onAuthenticationError?: (username: string) => void
}

export function multiply(a: number, b: number): Promise<number> {
  return Sip.multiply(a, b)
}

export function login(
  username: string,
  password: string,
  domain: string
): Promise<void> {
  return Sip.login(username, password, domain)
}

type SipCall = {
  call: (remoteUri: string) => Promise<void>
  hangup: () => Promise<void>
}

export function useCall(callbacks: Callbacks = {}): SipCall {
  React.useEffect(() => {
    const eventEmitter = new NativeEventEmitter(Sip)

    const eventListeners = Object.entries(callbacks).map(
      ([event, callback]) => {
        console.log(event.slice(2))
        return eventEmitter.addListener(event.slice(2), callback)
      }
    )
    return () => eventListeners.forEach((listener) => listener.remove())
  }, [callbacks])

  return {
    call: (remoteUri: string) => Sip.outgoingCall(remoteUri),
    hangup: () => Sip.hangUp(),
  }
}
