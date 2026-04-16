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
  /** Pre-supplied image metadata: when the renderer encounters a
   *  block-level image whose url matches one of these entries it
   *  reserves the supplied width / height during measurement so
   *  there's no layout shift when the image finishes loading. */
  images?: ReadonlyArray<
    Readonly<{ url: string; width: Double; height: Double }>
  >
  /** When true the native side emits onLinkLongPress instead of
   *  showing the system link context menu. Derived automatically
   *  from whether the JS component receives an onLinkLongPress
   *  callback. */
  linkLongPressEnabled?: boolean
  markdown: string

  // Events
  onImagePress?: DirectEventHandler<
    Readonly<{ url: string; width: Double; height: Double }>
  >
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
