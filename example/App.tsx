import React from 'react';
import { NativeRouter, Route, Routes } from 'react-router-native';
import ScanDevices from './screens/ScanDevices'; // Your main App component
import PeripheralDetails from './screens/PeripheralDetails'; // The component to show peripheral details

const App = () => {
  return (
    <NativeRouter>
      <Routes>
        <Route path="/" element={<ScanDevices />} />
        <Route path="/details" element={<PeripheralDetails />} />
      </Routes>
    </NativeRouter>
  );
}

export default App;
