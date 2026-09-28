import AsyncStorage from "@react-native-async-storage/async-storage";
import { Redirect } from "expo-router";
import { useEffect, useState } from "react";
import { PENDING_INVITE_TOKEN_KEY } from "@/lib/roomInvites";

export default function AuthCallback() {
  const [href, setHref] = useState<string | null>(null);

  useEffect(() => {
    void AsyncStorage.getItem(PENDING_INVITE_TOKEN_KEY).then((token) => {
      setHref(token ? `/invite/${token}` : "/(tabs)/home");
    });
  }, []);

  if (!href) return null;
  return <Redirect href={href as any} />;
}
