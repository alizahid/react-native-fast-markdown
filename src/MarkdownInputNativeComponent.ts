import {
  codegenNativeCommands,
  codegenNativeComponent,
  type HostComponent,
  type ViewProps,
} from 'react-native'
import {
  type DirectEventHandler,
  type Double,
  type Int32,
} from 'react-native/Libraries/Types/CodegenTypes'

export interface MarkdownInputViewNativeProps extends ViewProps {
  autoCapitalize?: string
  autoFocus?: boolean
  cursorColor?: string
  customTags?: ReadonlyArray<string>
  defaultValue?: string
  editable?: boolean
  multiline?: boolean
  onChangeMarkdown?: DirectEventHandler<Readonly<{ markdown: string }>>
  onChangeSelection?: DirectEventHandler<
    Readonly<{ start: Double; end: Double }>
  >
  onChangeState?: DirectEventHandler<
    Readonly<{
      bold: boolean
      italic: boolean
      strikethrough: boolean
      code: boolean
      linkUrl: string
      heading: Int32
      list: string
    }>
  >

  // Events
  onChangeText?: DirectEventHandler<Readonly<{ text: string }>>
  onEditorBlur?: DirectEventHandler<Readonly<{ focused: boolean }>>
  onEditorFocus?: DirectEventHandler<Readonly<{ focused: boolean }>>
  onLinkDetected?: DirectEventHandler<Readonly<{ url: string }>>
  onMentionQuery?: DirectEventHandler<Readonly<{ query: string }>>
  placeholder?: string
  placeholderTextColor?: string
  scrollEnabled?: boolean
  selectionColor?: string
  styles?: string // JSON-serialized MarkdownStyle
}

type MarkdownInputViewComponent = HostComponent<MarkdownInputViewNativeProps>

interface NativeCommands {
  blur: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  focus: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  insertCustomTag: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    tag: string,
    propsJson: string,
  ) => void
  insertLink: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    url: string,
    text: string,
  ) => void
  insertMention: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    user: string,
  ) => void
  insertSpoiler: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  removeLink: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  setSelection: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    start: Int32,
    end: Int32,
  ) => void
  setValue: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    value: string,
  ) => void
  toggleBlockquote: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
  ) => void
  toggleBold: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  toggleCode: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  toggleHeading: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    level: Int32,
  ) => void
  toggleItalic: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  toggleOrderedList: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
  ) => void
  toggleStrikethrough: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
  ) => void
  toggleUnorderedList: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
  ) => void
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    'focus',
    'blur',
    'setValue',
    'setSelection',
    'toggleBold',
    'toggleItalic',
    'toggleStrikethrough',
    'toggleCode',
    'toggleHeading',
    'toggleOrderedList',
    'toggleUnorderedList',
    'toggleBlockquote',
    'insertLink',
    'removeLink',
    'insertMention',
    'insertSpoiler',
    'insertCustomTag',
  ],
})

export default codegenNativeComponent<MarkdownInputViewNativeProps>(
  'MarkdownInputView',
) as MarkdownInputViewComponent
