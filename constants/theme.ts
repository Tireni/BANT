import { darkColors, lightColors } from "./colors";

export type BantTheme = ReturnType<typeof makeTheme>;

export function makeTheme(isDark: boolean) {
  const colors = isDark ? darkColors : lightColors;
  return {
    isDark,
    colors,
    radius: { sm: 10, md: 16, card: 20, lg: 24, sheet: 28 },
    spacing: { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24, xxxl: 32 },
    shadow: {
      shadowColor: "#000",
      shadowOffset: { width: 0, height: 8 },
      shadowOpacity: isDark ? 0.28 : 0.08,
      shadowRadius: 20,
      elevation: 4
    }
  };
}
