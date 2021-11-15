import React from 'react'
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native'
import type { DtmfChar } from 'react-native-sip'

interface DialpadProps {
  sendDtmf: (dtmf: DtmfChar) => Promise<void>
}

export default function Dialpad(props: DialpadProps): JSX.Element {
  const { sendDtmf } = props

  return (
    <View style={styles.container}>
      {[
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['*', '0', '#'],
      ].map((row, i) => (
        <View key={i} style={styles.row}>
          {row.map((n) => (
            <TouchableOpacity
              key={n}
              onPress={() => sendDtmf(n)}
              style={styles.roundButton}
            >
              <Text>{n}</Text>
            </TouchableOpacity>
          ))}
        </View>
      ))}
    </View>
  )
}

const buttonSize = 60

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    margin: 10,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'center',
  },
  roundButton: {
    alignItems: 'center',
    backgroundColor: 'green',
    borderRadius: buttonSize,
    height: buttonSize,
    justifyContent: 'center',
    margin: 5,
    padding: 10,
    width: buttonSize,
  },
})
