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

  // Events
  onLinkLongPress?: DirectEventHandler<Readonly<{ url: string; title: string }>>
  onLinkPress?: DirectEventHandler<Readonly<{ url: string; title: string }>>
  onMentionPress?: DirectEventHandler<
    Readonly<{
      mentionType: string // 'user' | 'channel' | 'command'
      // Named with a prefix so it doesn't collide with ObjC's reserved
      // `id` typedef when codegen generates the C++ event struct.
      mentionId: string
      mentionName: string
      // JSON-serialized Record<string, string> of extra props beyond id/name.
      // Fabric event payloads can't carry arbitrary dicts, so the JS side
      // parses this in <Markdown>'s onMentionPress wrapper.
      mentionProps: string
    }>
  >
  onTaskListItemPress?: DirectEventHandler<
    Readonly<{ index: Double; checked: boolean }>
  >
  styles?: string // JSON-serialized MarkdownStyle
}

export default codegenNativeComponent<MarkdownViewNativeProps>(
  'MarkdownView',
) as HostComponent<MarkdownViewNativeProps>
