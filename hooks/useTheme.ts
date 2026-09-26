import { useColorScheme } from "react-native";
import { makeTheme } from "@/constants/theme";
import { useBantStore } from "@/store/useBantStore";

export function useTheme() {
  const system = useColorScheme();
  const preference = useBantStore((state) => state.themePreference);
  const isDark = preference === "dark" || (preference === "system" && system === "dark");
  return makeTheme(isDark);
}
