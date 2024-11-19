import React from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
  Button,
} from 'react-native';
import {useStartScan} from './src/bluetooth';

function App(): React.JSX.Element {
  const startScan = useStartScan();

  return (
    <SafeAreaView style={{backgroundColor: '#fff'}}>
      <Text style={{textAlign: 'center'}}>BleManager</Text>
      <Button title="Scan Nearby" onPress={startScan} />
    </SafeAreaView>
  );
}

export default App;
