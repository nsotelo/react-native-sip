import React from 'react'

import { useSIP, useCall } from 'react-native-sip'
import { StyleSheet, View, Button, TextInput } from 'react-native'

type CallState =
  | 'initial'
  | 'requested'
  | 'ringing'
  | 'in-progress'
  | 'released'

interface LoginProps {
  setLoggedIn: (authState: boolean) => void
}

function Login(props: LoginProps) {
  const [domain, setDomain] = React.useState('')
  const [password, setPassword] = React.useState('')
  const [username, setUsername] = React.useState('')
  const { setLoggedIn } = props
  const { login } = useSIP()

  function handleLogin() {
    login(username, password, domain)
      .then(() => setLoggedIn(true))
      .catch((e) => {
        console.log(e)
        setLoggedIn(false)
      })
  }

  return (
    <View>
      <TextInput
        autoCapitalize="none"
        onChangeText={setDomain}
        placeholder="SIP Domain"
        style={styles.input}
        textContentType="URL"
        value={domain}
      />
      <TextInput
        autoCapitalize="none"
        onChangeText={setUsername}
        placeholder="Username"
        style={styles.input}
        textContentType="username"
        value={username}
      />
      <TextInput
        autoCapitalize="none"
        autoCorrect={false}
        onChangeText={setPassword}
        placeholder="Password"
        secureTextEntry
        style={styles.input}
        textContentType="password"
        value={password}
      />
      <Button
        onPress={handleLogin}
        title="Login"
        disabled={!(domain && username && password)}
      />
    </View>
  )
}

function PhoneCall() {
  const [callState, setCallState] = React.useState<CallState>('initial')
  const [remoteUri, setRemoteUri] = React.useState('')

  const canCall = remoteUri && callState === 'initial'
  const canHangUp = ['ringing', 'in-progress'].includes(callState)

  const { call, hangup } = useCall({
    onCallRequested: () => setCallState('requested'),
    onCallRinging: () => setCallState('ringing'),
    onCallConnected: () => setCallState('in-progress'),
    onCallReleased: () => {
      setCallState('released')
      setTimeout(() => setCallState('initial'), 200)
    },
  })

  function outboundCall() {
    call(remoteUri)
  }

  return (
    <View>
      <TextInput
        autoCapitalize="none"
        onChangeText={setRemoteUri}
        placeholder="Remote SIP URI"
        style={styles.input}
        textContentType="emailAddress"
        value={remoteUri}
      />
      <View style={styles.buttonContainer}>
        <View style={styles.button}>
          <Button onPress={outboundCall} title="Call" disabled={!canCall} />
        </View>
        <View style={styles.button}>
          <Button onPress={hangup} title="Hang up" disabled={!canHangUp} />
        </View>
      </View>
    </View>
  )
}

export default function SIPDemo() {
  const [loggedIn, setLoggedIn] = React.useState<boolean>(false)

  return (
    <View style={styles.container}>
      {!loggedIn && <Login setLoggedIn={setLoggedIn} />}
      {loggedIn && <PhoneCall />}
    </View>
  )
}

const styles = StyleSheet.create({
  button: {
    width: 100,
    height: 60,
    margin: 20,
  },
  buttonContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingVertical: 100,
  },
  input: {
    width: 200,
    borderWidth: 1,
    borderRadius: 6,
    margin: 6,
  },
})
