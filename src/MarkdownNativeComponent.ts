import type { HostComponent, ViewProps } from "react-native";
import { codegenNativeComponent } from "react-native";
import type {
  DirectEventHandler,
  Double,
} from "react-native/Libraries/Types/CodegenTypes";

export interface MarkdownViewNativeProps extends ViewProps {
  customTags?: readonly string[];
  markdown: string;
  markdownStyle?: string; // JSON-serialized MarkdownStyle
  onLinkLongPress?: DirectEventHandler<
    Readonly<{ url: string; title: string }>
  >;

  // Events
  onLinkPress?: DirectEventHandler<Readonly<{ url: string; title: string }>>;
  onMentionPress?: DirectEventHandler<Readonly<{ user: string }>>;
  onTaskListItemPress?: DirectEventHandler<
    Readonly<{ index: Double; checked: boolean }>
  >;
}

export default codegenNativeComponent<MarkdownViewNativeProps>(
  "MarkdownView"
) as HostComponent<MarkdownViewNativeProps>;
