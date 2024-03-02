import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useLocation } from 'react-router-native';

// Define interfaces for your peripheral's properties
interface Characteristic {
  characteristic: string;
  // Add any other characteristic properties you need
}

interface Service {
  uuid: string;
  characteristics: Characteristic[];
  // Add any other service properties you need
}

interface Peripheral {
  id: string;
  name: string;
  services: Service[];
  // Add any other peripheral properties you need
}

// Props expected by PeripheralDetails component
interface PeripheralDetailsProps {
  route: {
    params: {
      peripheral: Peripheral;
    };
  };
}


const PeripheralDetails = () => {
    //const { peripheral } = route.params;
    const location = useLocation();
    console.log(location);
  
    const peripheral: Peripheral = {
      id: "Peripheral1",
      name: "Dummy Peripheral",
      services: [
        {
          uuid: "Service1UUID",
          characteristics: [
            {
              characteristic: "Characteristic1",
            },
            {
              characteristic: "Characteristic2",
            },
          ],
        },
        {
          uuid: "Service2UUID",
          characteristics: [
            {
              characteristic: "Characteristic3",
              
            },
          ],
        },
      ],
    };

    return (
      <View style={styles.container}>
        <Text style={styles.title}>Peripheral Details</Text>
        <Text style={styles.detail}>Name: {peripheral.name}</Text>
        <Text style={styles.detail}>ID: {peripheral.id}</Text>
        {peripheral.services.map((service, index) => (
          <View key={index} style={styles.serviceContainer}>
            <Text style={styles.serviceTitle}>Service: {service.uuid}</Text>
            {service.characteristics.map((characteristic, charIndex) => (
              <Text key={charIndex} style={styles.characteristic}>
                Characteristic: {characteristic.characteristic}
              </Text>
            ))}
          </View>
        ))}
      </View>
    );
  };
  
  // Add some basic styling
  const styles = StyleSheet.create({
    container: {
      flex: 1,
      padding: 20,
    },
    title: {
      fontSize: 20,
      fontWeight: 'bold',
    },
    detail: {
      marginTop: 5,
      fontSize: 16,
    },
    serviceContainer: {
      marginTop: 15,
    },
    serviceTitle: {
      fontSize: 18,
      fontWeight: 'bold',
    },
    characteristic: {
      fontSize: 16,
    },
  });
  
  export default PeripheralDetails;
  