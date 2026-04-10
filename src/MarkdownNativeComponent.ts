import {
  codegenNativeComponent,
  type HostComponent,
  type ViewProps,
} from 'react-native'
import {
  type DirectEventHandler,
  type Double,
} from 'react-native/Libraries/Types/CodegenTypes'

export interface MarkdownViewNativeProps extends ViewProps {
  customTags?: ReadonlyArray<string>
  markdown: string
  markdownStyle?: string // JSON-serialized MarkdownStyle
  onLinkLongPress?: DirectEventHandler<Readonly<{ url: string; title: string }>>

  // Events
  onLinkPress?: DirectEventHandler<Readonly<{ url: string; title: string }>>
  onMentionPress?: DirectEventHandler<Readonly<{ user: string }>>
  onTaskListItemPress?: DirectEventHandler<
    Readonly<{ index: Double; checked: boolean }>
  >
}

export default codegenNativeComponent<MarkdownViewNativeProps>(
  'MarkdownView',
) as HostComponent<MarkdownViewNativeProps>
