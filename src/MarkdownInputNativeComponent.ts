import type { HostComponent, ViewProps } from 'react-native'
import type {
  DirectEventHandler,
  Double,
  Int32,
} from 'react-native/Libraries/Types/CodegenTypes'
import {
  codegenNativeComponent,
  codegenNativeCommands,
} from 'react-native'

export interface MarkdownInputViewNativeProps extends ViewProps {
  defaultValue?: string
  placeholder?: string
  placeholderTextColor?: string
  markdownStyle?: string // JSON-serialized MarkdownStyle
  customTags?: ReadonlyArray<string>
  editable?: boolean
  multiline?: boolean
  autoFocus?: boolean
  scrollEnabled?: boolean
  autoCapitalize?: string
  cursorColor?: string
  selectionColor?: string

  // Events
  onChangeText?: DirectEventHandler<Readonly<{ text: string }>>
  onChangeMarkdown?: DirectEventHandler<Readonly<{ markdown: string }>>
  onChangeSelection?: DirectEventHandler<
    Readonly<{ start: Double; end: Double }>
  >
  onChangeState?: DirectEventHandler<
    Readonly<{
      bold: boolean
      italic: boolean
      strikethrough: boolean
      underline: boolean
      code: boolean
      linkUrl: string
      heading: Int32
      list: string
    }>
  >
  onLinkDetected?: DirectEventHandler<Readonly<{ url: string }>>
  onMentionQuery?: DirectEventHandler<Readonly<{ query: string }>>
  onFocus?: DirectEventHandler<Readonly<{ target: Int32 }>>
  onBlur?: DirectEventHandler<Readonly<{ target: Int32 }>>
}

type MarkdownInputViewComponent =
  HostComponent<MarkdownInputViewNativeProps>

interface NativeCommands {
  focus: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  blur: (viewRef: React.ElementRef<MarkdownInputViewComponent>) => void
  setValue: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    value: string
  ) => void
  setSelection: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    start: Int32,
    end: Int32
  ) => void
  toggleBold: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  toggleItalic: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  toggleStrikethrough: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  toggleUnderline: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  toggleCode: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  toggleHeading: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    level: Int32
  ) => void
  toggleOrderedList: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  toggleUnorderedList: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  toggleBlockquote: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  insertLink: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    url: string,
    text: string
  ) => void
  removeLink: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  insertMention: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    user: string
  ) => void
  insertSpoiler: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>
  ) => void
  insertCustomTag: (
    viewRef: React.ElementRef<MarkdownInputViewComponent>,
    tag: string,
    propsJson: string
  ) => void
}

export const Commands =
  codegenNativeCommands<NativeCommands>({
    supportedCommands: [
      'focus',
      'blur',
      'setValue',
      'setSelection',
      'toggleBold',
      'toggleItalic',
      'toggleStrikethrough',
      'toggleUnderline',
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
  'MarkdownInputView'
) as MarkdownInputViewComponent
