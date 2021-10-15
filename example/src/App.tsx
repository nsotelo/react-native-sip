import React from 'react'

import { SIPProvider } from 'react-native-sip'
import SIPDemo from './sip'

export default function App() {
  return (
    <SIPProvider>
      <SIPDemo />
    </SIPProvider>
  )
}
