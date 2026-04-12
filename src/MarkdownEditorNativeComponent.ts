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

export interface MarkdownEditorViewNativeProps extends ViewProps {
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

type MarkdownEditorViewComponent = HostComponent<MarkdownEditorViewNativeProps>

interface NativeCommands {
  blur: (viewRef: React.ElementRef<MarkdownEditorViewComponent>) => void
  focus: (viewRef: React.ElementRef<MarkdownEditorViewComponent>) => void
  insertCustomTag: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
    tag: string,
    propsJson: string,
  ) => void
  insertLink: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
    url: string,
    text: string,
  ) => void
  insertMention: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
    user: string,
  ) => void
  insertSpoiler: (viewRef: React.ElementRef<MarkdownEditorViewComponent>) => void
  removeLink: (viewRef: React.ElementRef<MarkdownEditorViewComponent>) => void
  setSelection: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
    start: Int32,
    end: Int32,
  ) => void
  setValue: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
    value: string,
  ) => void
  toggleBlockquote: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
  ) => void
  toggleBold: (viewRef: React.ElementRef<MarkdownEditorViewComponent>) => void
  toggleCode: (viewRef: React.ElementRef<MarkdownEditorViewComponent>) => void
  toggleHeading: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
    level: Int32,
  ) => void
  toggleItalic: (viewRef: React.ElementRef<MarkdownEditorViewComponent>) => void
  toggleOrderedList: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
  ) => void
  toggleStrikethrough: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
  ) => void
  toggleUnorderedList: (
    viewRef: React.ElementRef<MarkdownEditorViewComponent>,
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

export default codegenNativeComponent<MarkdownEditorViewNativeProps>(
  'MarkdownEditorView',
) as MarkdownEditorViewComponent
