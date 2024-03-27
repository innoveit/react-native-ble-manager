import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import ScanDevicesScreen from './components/ScanDevicesScreen';
import PeripheralDetailsScreen from './components/PeripheralDetailsScreen';

const Stack = createNativeStackNavigator();

const App = () => {
  return (
    <NavigationContainer>
            <Stack.Navigator>
                <Stack.Screen
                    name="ScanDevices"
                    component={ScanDevicesScreen}
                />
                <Stack.Screen
                    name="PeripheralDetails"
                    component={PeripheralDetailsScreen}
                />
            </Stack.Navigator>
        </NavigationContainer>
  );
}

export default App;
