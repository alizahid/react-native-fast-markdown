import {
  codegenNativeComponent,
  type CodegenTypes,
  type ViewProps,
} from 'react-native';

type UrlEvent = {
  url: string;
};

type ImageData = {
  url: string;
  width: CodegenTypes.Double;
  height: CodegenTypes.Double;
};

interface NativeProps extends ViewProps {
  markdown: string;
  stylesJson?: string;
  images?: ReadonlyArray<ImageData>;
  onLinkPress?: CodegenTypes.DirectEventHandler<UrlEvent>;
  onLinkLongPress?: CodegenTypes.DirectEventHandler<UrlEvent>;
  onImagePress?: CodegenTypes.DirectEventHandler<UrlEvent>;
}

export default codegenNativeComponent<NativeProps>('FastMarkdownView');
