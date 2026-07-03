import {
  type CodegenTypes,
  codegenNativeComponent,
  type ViewProps,
} from "react-native";

interface UrlEvent {
  url: string;
}

interface ImageData {
  height: CodegenTypes.Double;
  url: string;
  width: CodegenTypes.Double;
}

interface NativeProps extends ViewProps {
  images?: readonly ImageData[];
  markdown: string;
  onImagePress?: CodegenTypes.DirectEventHandler<UrlEvent>;
  onLinkLongPress?: CodegenTypes.DirectEventHandler<UrlEvent>;
  onLinkPress?: CodegenTypes.DirectEventHandler<UrlEvent>;
  stylesJson?: string;
}

export default codegenNativeComponent<NativeProps>("FastMarkdownView");
