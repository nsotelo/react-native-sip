import React from 'react'
import * as NativeWrapper from './native-wrapper'

interface SIPOperations {
  login: typeof NativeWrapper.login
}

const SIPContext = React.createContext<SIPOperations>({
  login: async () => undefined,
})

interface SIPProviderProps {
  children?: React.ReactNode
}
export function SIPProvider({ children = <></> }: SIPProviderProps) {
  const [initialised, setInitialised] = React.useState(false)

  React.useEffect(() => {
    NativeWrapper.Sip.initialise().then(() => setInitialised(true))
  }, [])

  const sipOperations = {
    login: NativeWrapper.login,
  }

  return initialised ? (
    <SIPContext.Provider value={sipOperations}>{children}</SIPContext.Provider>
  ) : (
    <></>
  )
}

export const useSIP = () => React.useContext(SIPContext)
