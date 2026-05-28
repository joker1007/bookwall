import { useTranslation } from "react-i18next";
import { ITEM_SIZE_MIN, ITEM_SIZE_MAX } from "@/stores/uiStore";

interface ItemSizeSliderProps {
  value: number;
  onChange: (next: number) => void;
}

export function ItemSizeSlider({ value, onChange }: ItemSizeSliderProps) {
  const { t } = useTranslation();
  return (
    <label className="flex h-10 items-center gap-2 rounded-md border border-input bg-background px-3 text-sm">
      <span className="text-muted-foreground">{t("books.itemSize.label")}</span>
      <input
        type="range"
        min={ITEM_SIZE_MIN}
        max={ITEM_SIZE_MAX}
        step={8}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        aria-label={t("books.itemSize.label")}
        className="h-2 w-32 cursor-pointer appearance-none rounded-full bg-muted
          [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:appearance-none
          [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border [&::-webkit-slider-thumb]:border-foreground/60
          [&::-webkit-slider-thumb]:bg-foreground
          [&::-moz-range-thumb]:h-4 [&::-moz-range-thumb]:w-4 [&::-moz-range-thumb]:rounded-full
          [&::-moz-range-thumb]:border [&::-moz-range-thumb]:border-foreground/60 [&::-moz-range-thumb]:bg-foreground"
      />
      <span className="w-12 text-right tabular-nums text-muted-foreground">{value}px</span>
    </label>
  );
}
