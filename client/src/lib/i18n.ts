import i18n from "i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import { initReactI18next } from "react-i18next";
import ja from "@/locales/ja.json";
import en from "@/locales/en.json";

export type LanguageCode = "ja" | "en";
export const SUPPORTED_LANGUAGES: LanguageCode[] = ["ja", "en"];

void i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      ja: { translation: ja },
      en: { translation: en },
    },
    supportedLngs: SUPPORTED_LANGUAGES,
    fallbackLng: "ja",
    interpolation: { escapeValue: false },
    detection: {
      order: ["localStorage", "navigator"],
      lookupLocalStorage: "bookwall-language",
      caches: ["localStorage"],
    },
  });

export default i18n;
