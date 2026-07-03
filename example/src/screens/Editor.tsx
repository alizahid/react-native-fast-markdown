import { useState } from "react";
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
} from "react-native";
import {
  FastMarkdownEditor,
  type MarkdownContainerStyle,
  mergeStyles,
  useFastMarkdownEditor,
} from "react-native-fast-markdown";

const styles = mergeStyles();

const editorStyle: MarkdownContainerStyle = {
  backgroundColor: "#F9FAFB",
  fontSize: 16,
  padding: 12,
};

export function Editor() {
  const editor = useFastMarkdownEditor();
  const [status, setStatus] = useState("idle");
  const [selection, setSelection] = useState("0:0");
  const [lastMarkdown, setLastMarkdown] = useState("");

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      style={sheet.container}
    >
      <ScrollView keyboardDismissMode="interactive" style={sheet.scroll}>
        <Text style={sheet.status}>
          {status} · sel {selection}
        </Text>
        <FastMarkdownEditor
          onBlur={() => setStatus("blurred")}
          onChangeSelection={(range) =>
            setSelection(`${range.start}:${range.end}`)
          }
          onChangeText={(text) => setLastMarkdown(text)}
          onFocus={() => setStatus("focused")}
          placeholder="Write something..."
          placeholderTextColor="#9CA3AF"
          ref={editor.ref}
          style={editorStyle}
          styles={styles}
        />
        <Text style={sheet.output} testID="markdown-output">
          {lastMarkdown || "(empty)"}
        </Text>
      </ScrollView>
      <ScrollView
        contentContainerStyle={sheet.toolbarContent}
        horizontal
        keyboardShouldPersistTaps="always"
        style={sheet.toolbar}
      >
        <ToolbarButton label="Focus" onPress={editor.focus} />
        <ToolbarButton label="Blur" onPress={editor.blur} />
        <ToolbarButton
          label="Set value"
          onPress={() => editor.setValue("Hello **world** from setValue")}
        />
        <ToolbarButton
          label="Select 0-5"
          onPress={() => editor.setSelection(0, 5)}
        />
        <ToolbarButton
          label="Get markdown"
          onPress={async () => {
            const markdown = await editor.getMarkdown();
            setLastMarkdown(markdown);
          }}
        />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function ToolbarButton({
  label,
  onPress,
}: {
  label: string;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={sheet.button}>
      <Text style={sheet.buttonText}>{label}</Text>
    </Pressable>
  );
}

const sheet = StyleSheet.create({
  container: {
    flex: 1,
  },
  scroll: {
    flex: 1,
    padding: 12,
  },
  status: {
    color: "#6B7280",
    fontSize: 12,
    marginBottom: 8,
  },
  output: {
    color: "#374151",
    fontFamily: Platform.OS === "ios" ? "Menlo" : "monospace",
    fontSize: 12,
    marginTop: 12,
  },
  toolbar: {
    borderTopColor: "#E5E7EB",
    borderTopWidth: 1,
    flexGrow: 0,
  },
  toolbarContent: {
    gap: 6,
    padding: 8,
  },
  button: {
    backgroundColor: "#F3F4F6",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  buttonText: {
    color: "#111827",
    fontSize: 13,
  },
});
