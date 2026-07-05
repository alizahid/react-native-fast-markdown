import {
  type CodegenTypes,
  type ColorValue,
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
  allowFontScaling?: CodegenTypes.WithDefault<boolean, true>;
  autoCapitalize?: CodegenTypes.WithDefault<
    "none" | "sentences" | "words" | "characters",
    "sentences"
  >;
  autoCorrect?: CodegenTypes.WithDefault<boolean, true>;
  autoFocus?: CodegenTypes.WithDefault<boolean, false>;
  cursorColor?: ColorValue;
  defaultValue?: string;
  editable?: CodegenTypes.WithDefault<boolean, true>;
  /**
   * Autogrow cap in points; 0 = unbounded. Past it the editor scrolls.
   * Deliberately NOT named maxHeight: Yoga parses that key out of the same
   * raw-props bag, and the default 0 would clamp the node to zero height.
   */
  maxContentHeight?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
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
  placeholderTextColor?: ColorValue;
  scrollEnabled?: CodegenTypes.WithDefault<boolean, false>;
  selectionColor?: ColorValue;
  stylesJson?: string;
}

type EditorComponentType = HostComponent<NativeProps>;

interface NativeCommands {
  blur: (viewRef: React.ElementRef<EditorComponentType>) => void;
  focus: (viewRef: React.ElementRef<EditorComponentType>) => void;
  insertLink: (
    viewRef: React.ElementRef<EditorComponentType>,
    url: string,
    label: string
  ) => void;
  insertMarkdown: (
    viewRef: React.ElementRef<EditorComponentType>,
    value: string
  ) => void;
  insertMention: (
    viewRef: React.ElementRef<EditorComponentType>,
    trigger: string,
    label: string,
    url: string
  ) => void;
  removeLink: (viewRef: React.ElementRef<EditorComponentType>) => void;
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
    "insertLink",
    "insertMarkdown",
    "insertMention",
    "removeLink",
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
