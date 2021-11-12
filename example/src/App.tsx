import React from 'react'

import { SIPProvider } from 'react-native-sip-phone'
import SIPDemo from './sip'

export default function App() {
  return (
    <SIPProvider>
      <SIPDemo />
    </SIPProvider>
  )
}
