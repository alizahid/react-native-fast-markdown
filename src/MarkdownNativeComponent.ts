import type { HostComponent, ViewProps } from 'react-native'
import type { DirectEventHandler, Double } from 'react-native/Libraries/Types/CodegenTypes'
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent'

export interface MarkdownViewNativeProps extends ViewProps {
  markdown: string
  markdownStyle?: string // JSON-serialized MarkdownStyle
  customTags?: ReadonlyArray<string>

  // Events
  onLinkPress?: DirectEventHandler<
    Readonly<{ url: string; title: string }>
  >
  onLinkLongPress?: DirectEventHandler<
    Readonly<{ url: string; title: string }>
  >
  onMentionPress?: DirectEventHandler<Readonly<{ user: string }>>
  onTaskListItemPress?: DirectEventHandler<
    Readonly<{ index: Double; checked: boolean }>
  >
}

export default codegenNativeComponent<MarkdownViewNativeProps>(
  'MarkdownView'
) as HostComponent<MarkdownViewNativeProps>
