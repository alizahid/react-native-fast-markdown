import {
  type CodegenTypes,
  codegenNativeCommands,
  codegenNativeComponent,
  type HostComponent,
  type ViewProps,
} from "react-native";

interface TextEvent {
  text: string;
}

interface MarkdownEvent {
  markdown: string;
}

interface SelectionEvent {
  end: CodegenTypes.Int32;
  start: CodegenTypes.Int32;
}

interface StateEvent {
  headingLevel: CodegenTypes.Int32;
  isBlockQuote: boolean;
  isBold: boolean;
  isCodeBlock: boolean;
  isInlineCode: boolean;
  isItalic: boolean;
  isOrderedList: boolean;
  isSpoiler: boolean;
  isStrikethrough: boolean;
  isSubscript: boolean;
  isSuperscript: boolean;
  isUnorderedList: boolean;
}

interface UrlEvent {
  url: string;
}

interface MentionEvent {
  trigger: string;
}

interface MentionQueryEvent {
  query: string;
  trigger: string;
}

interface PasteEvent {
  // Codegen's event parser needs inline element types and rejects readonly
  // arrays (the props parser accepts both).
  images: {
    height: CodegenTypes.Double;
    url: string;
    width: CodegenTypes.Double;
  }[];
  text: string;
}

interface NativeProps extends ViewProps {
  autoCapitalize?: CodegenTypes.WithDefault<
    "none" | "sentences" | "words" | "characters",
    "sentences"
  >;
  autoCorrect?: CodegenTypes.WithDefault<boolean, true>;
  autoFocus?: CodegenTypes.WithDefault<boolean, false>;
  /** Processed ARGB int; 0 = unset. */
  cursorColor?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  defaultValue?: string;
  editable?: CodegenTypes.WithDefault<boolean, true>;
  mentionTriggers?: readonly string[];
  multiline?: CodegenTypes.WithDefault<boolean, true>;
  onEditorBlur?: CodegenTypes.DirectEventHandler<null>;
  onEditorChangeMarkdown?: CodegenTypes.DirectEventHandler<MarkdownEvent>;
  onEditorChangeSelection?: CodegenTypes.DirectEventHandler<SelectionEvent>;
  onEditorChangeState?: CodegenTypes.DirectEventHandler<StateEvent>;
  onEditorChangeText?: CodegenTypes.DirectEventHandler<TextEvent>;
  onEditorFocus?: CodegenTypes.DirectEventHandler<null>;
  onEditorLinkDetected?: CodegenTypes.DirectEventHandler<UrlEvent>;
  onEditorMentionChange?: CodegenTypes.DirectEventHandler<MentionQueryEvent>;
  onEditorMentionEnd?: CodegenTypes.DirectEventHandler<MentionEvent>;
  onEditorMentionStart?: CodegenTypes.DirectEventHandler<MentionEvent>;
  onEditorPaste?: CodegenTypes.DirectEventHandler<PasteEvent>;
  placeholder?: string;
  /** Processed ARGB int; 0 = unset. */
  placeholderTextColor?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  scrollEnabled?: CodegenTypes.WithDefault<boolean, false>;
  /** Processed ARGB int; 0 = unset. */
  selectionColor?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  stylesJson?: string;
}

type EditorComponentType = HostComponent<NativeProps>;

interface NativeCommands {
  blur: (viewRef: React.ElementRef<EditorComponentType>) => void;
  focus: (viewRef: React.ElementRef<EditorComponentType>) => void;
  setSelection: (
    viewRef: React.ElementRef<EditorComponentType>,
    start: CodegenTypes.Int32,
    end: CodegenTypes.Int32
  ) => void;
  setValue: (
    viewRef: React.ElementRef<EditorComponentType>,
    value: string
  ) => void;
  toggleBlockQuote: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleBold: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleCode: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleCodeBlock: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleHeading: (
    viewRef: React.ElementRef<EditorComponentType>,
    level: CodegenTypes.Int32
  ) => void;
  toggleItalic: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleOrderedList: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleSpoiler: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleStrikethrough: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleSubscript: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleSuperscript: (viewRef: React.ElementRef<EditorComponentType>) => void;
  toggleUnorderedList: (viewRef: React.ElementRef<EditorComponentType>) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    "blur",
    "focus",
    "setSelection",
    "setValue",
    "toggleBlockQuote",
    "toggleBold",
    "toggleCode",
    "toggleCodeBlock",
    "toggleHeading",
    "toggleItalic",
    "toggleOrderedList",
    "toggleSpoiler",
    "toggleStrikethrough",
    "toggleSubscript",
    "toggleSuperscript",
    "toggleUnorderedList",
  ],
});

export default codegenNativeComponent<NativeProps>("FastMarkdownEditor");
