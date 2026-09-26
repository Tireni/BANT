import { ReactNode } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, ViewStyle } from "react-native";
import { useTheme } from "@/hooks/useTheme";

type Props = {
  title: string;
  onPress: () => void;
  variant?: "primary" | "secondary" | "ghost" | "danger";
  icon?: ReactNode;
  disabled?: boolean;
  loading?: boolean;
  style?: ViewStyle;
};

export function BantButton({ title, onPress, variant = "primary", icon, disabled, loading, style }: Props) {
  const theme = useTheme();
  const styles = makeStyles(theme);
  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled || loading}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        styles[variant],
        (pressed || disabled) && { opacity: disabled ? 0.55 : 0.85, transform: [{ scale: 0.98 }] },
        style
      ]}
    >
      {loading ? <ActivityIndicator color="#fff" /> : icon}
      <Text style={[styles.text, variant === "ghost" && { color: theme.colors.blue }]}>{title}</Text>
    </Pressable>
  );
}

const makeStyles = (theme: ReturnType<typeof useTheme>) =>
  StyleSheet.create({
    button: {
      minHeight: 50,
      borderRadius: theme.radius.md,
      alignItems: "center",
      justifyContent: "center",
      flexDirection: "row",
      gap: 8,
      paddingHorizontal: 18
    },
    primary: { backgroundColor: theme.colors.blue },
    secondary: { backgroundColor: theme.colors.mint },
    ghost: { backgroundColor: theme.colors.soft, borderWidth: 1, borderColor: theme.colors.border },
    danger: { backgroundColor: theme.colors.danger },
    text: { color: "#fff", fontFamily: "PlusJakartaSans_700Bold", fontSize: 15, lineHeight: 20 }
  });
