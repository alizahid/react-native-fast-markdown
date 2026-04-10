import { NavigationContainer } from '@react-navigation/native'
import { createNativeStackNavigator } from '@react-navigation/native-stack'
import { BasicRendererScreen } from './examples/BasicRenderer'
import { CustomComponentsScreen } from './examples/CustomComponents'
import { EditorScreen } from './examples/Editor'
import { GFMFeaturesScreen } from './examples/GfmFeatures'
import { PerformanceScreen } from './examples/Performance'
import { StylingScreen } from './examples/Styling'
import { HomeScreen } from './HomeScreen'

export interface RootStackParamList {
  BasicRenderer: undefined
  CustomComponents: undefined
  Editor: undefined
  GFMFeatures: undefined
  Home: undefined
  Performance: undefined
  Styling: undefined
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
          component={HomeScreen}
          name="Home"
          options={{ title: 'Markdown Examples' }}
        />
        <Stack.Screen
          component={BasicRendererScreen}
          name="BasicRenderer"
          options={{ title: 'Basic Rendering' }}
        />
        <Stack.Screen
          component={GFMFeaturesScreen}
          name="GFMFeatures"
          options={{ title: 'GFM Features' }}
        />
        <Stack.Screen
          component={CustomComponentsScreen}
          name="CustomComponents"
          options={{ title: 'Custom Components' }}
        />
        <Stack.Screen
          component={StylingScreen}
          name="Styling"
          options={{ title: 'Custom Styling' }}
        />
        <Stack.Screen
          component={EditorScreen}
          name="Editor"
          options={{ title: 'Markdown Editor' }}
        />
        <Stack.Screen
          component={PerformanceScreen}
          name="Performance"
          options={{ title: 'Performance' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  )
}
