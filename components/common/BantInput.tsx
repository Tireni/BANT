import { useEffect, useState } from "react";
import { Platform, TextInput, TextInputProps, StyleSheet, View } from "react-native";
import { useTheme } from "@/hooks/useTheme";

export function BantInput(props: TextInputProps) {
  const theme = useTheme();
  const styles = makeStyles(theme);
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    if (Platform.OS !== "web" || typeof document === "undefined" || document.getElementById("bant-input-focus-styles")) return;
    const style = document.createElement("style");
    style.id = "bant-input-focus-styles";
    style.textContent = `
      input, textarea, select {
        outline: none !important;
        -webkit-tap-highlight-color: transparent;
      }
      input:focus, textarea:focus, select:focus,
      input:focus-visible, textarea:focus-visible, select:focus-visible {
        outline: none !important;
      }
      input:-webkit-autofill,
      input:-webkit-autofill:hover,
      input:-webkit-autofill:focus,
      textarea:-webkit-autofill,
      textarea:-webkit-autofill:hover,
      textarea:-webkit-autofill:focus {
        -webkit-text-fill-color: #F8FAFC !important;
        caret-color: #F8FAFC;
        transition: background-color 9999s ease-out 0s;
        box-shadow: 0 0 0 1000px #151B23 inset, 0 0 0 2px rgba(34, 163, 255, 0.14) !important;
        border-radius: 16px;
      }
    `;
    document.head.appendChild(style);
  }, []);

  return (
    <View style={[styles.wrap, focused && styles.wrapFocused]}>
      <TextInput
        {...props}
        placeholderTextColor={theme.colors.muted}
        style={styles.input}
        selectionColor={theme.colors.blue}
        onFocus={(event) => {
          setFocused(true);
          props.onFocus?.(event);
        }}
        onBlur={(event) => {
          setFocused(false);
          props.onBlur?.(event);
        }}
      />
    </View>
  );
}

const makeStyles = (theme: ReturnType<typeof useTheme>) =>
  StyleSheet.create({
    wrap: {
      minHeight: 54,
      borderRadius: theme.radius.md,
      backgroundColor: theme.colors.surface,
      borderWidth: 1,
      borderColor: theme.colors.border,
      justifyContent: "center",
      paddingHorizontal: 16,
      shadowColor: theme.colors.blue,
      shadowOffset: { width: 0, height: 0 },
      shadowOpacity: 0,
      shadowRadius: 0,
      ...(Platform.OS === "web" ? {
        transitionProperty: "border-color, box-shadow, shadow-opacity",
        transitionDuration: "160ms"
      } as any : {})
    },
    wrapFocused: {
      borderColor: theme.colors.blue,
      shadowOpacity: theme.isDark ? 0.18 : 0.12,
      shadowRadius: 7,
      boxShadow: `0 0 0 2px ${theme.isDark ? "rgba(34, 163, 255, 0.14)" : "rgba(14, 150, 246, 0.12)"}` as never
    },
    input: {
      color: theme.colors.text,
      fontSize: 15,
      fontFamily: "PlusJakartaSans_500Medium",
      outlineStyle: "none" as never,
      outlineWidth: 0 as never,
      boxShadow: "none" as never
    }
  });
