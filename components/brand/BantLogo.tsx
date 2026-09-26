import { Image, ImageStyle, StyleProp } from "react-native";

const horizontal = require("../../assets/brand/bant-logo-horizontal.png");
const mascot = require("../../assets/brand/bant-mascot.png");
const wordmark = require("../../assets/brand/bant-wordmark.png");
const reverse = require("../../assets/brand/bant-logo-reverse.png");

export function BantLogo({ variant = "horizontal", style }: { variant?: "horizontal" | "mascot" | "wordmark" | "reverse"; style?: StyleProp<ImageStyle> }) {
  const source = variant === "mascot" ? mascot : variant === "wordmark" ? wordmark : variant === "reverse" ? reverse : horizontal;
  return <Image source={source} resizeMode="contain" style={style} />;
}
