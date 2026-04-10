import { NavigationContainer } from '@react-navigation/native'
import { createNativeStackNavigator } from '@react-navigation/native-stack'

import { HomeScreen } from './HomeScreen'
import { BasicRendererScreen } from './examples/BasicRenderer'
import { GFMFeaturesScreen } from './examples/GFMFeatures'
import { CustomComponentsScreen } from './examples/CustomComponents'
import { StylingScreen } from './examples/Styling'
import { EditorScreen } from './examples/Editor'
import { PerformanceScreen } from './examples/Performance'

export type RootStackParamList = {
  Home: undefined
  BasicRenderer: undefined
  GFMFeatures: undefined
  CustomComponents: undefined
  Styling: undefined
  Editor: undefined
  Performance: undefined
}

const Stack = createNativeStackNavigator<RootStackParamList>()

export function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator
        screenOptions={{
          headerBackTitle: 'Back',
          headerTintColor: '#111',
          headerTitleStyle: { fontWeight: '600' },
        }}
      >
        <Stack.Screen
          name="Home"
          component={HomeScreen}
          options={{ title: 'Markdown Examples' }}
        />
        <Stack.Screen
          name="BasicRenderer"
          component={BasicRendererScreen}
          options={{ title: 'Basic Rendering' }}
        />
        <Stack.Screen
          name="GFMFeatures"
          component={GFMFeaturesScreen}
          options={{ title: 'GFM Features' }}
        />
        <Stack.Screen
          name="CustomComponents"
          component={CustomComponentsScreen}
          options={{ title: 'Custom Components' }}
        />
        <Stack.Screen
          name="Styling"
          component={StylingScreen}
          options={{ title: 'Custom Styling' }}
        />
        <Stack.Screen
          name="Editor"
          component={EditorScreen}
          options={{ title: 'Markdown Editor' }}
        />
        <Stack.Screen
          name="Performance"
          component={PerformanceScreen}
          options={{ title: 'Performance' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  )
}
