import type { ReactNode } from "react";
import { Label } from "@/components/ui/label";
import { Toggle } from "@/components/ui/toggle";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { Button } from "@/components/ui/button";
import {
  READER_FONT_SIZE_MIN,
  READER_FONT_SIZE_MAX,
  READER_FONT_SIZE_STEP,
} from "@/types/api";

interface ReaderOptionFieldProps<V extends string> {
  label: string;
  value: V;
  options: readonly V[];
  optionLabel: (value: V) => string;
  onChange: (value: V) => void;
  disabled?: boolean;
  // Most option sets wrap (theme / scale / writing-mode); the two-item
  // direction toggle stays on one line.
  wrap?: boolean;
  hint?: ReactNode;
}

// Labeled single-select ToggleGroup over a fixed, validated option set.
// Used for direction / scale / theme / writing-mode in every reader settings
// surface.
export function ReaderOptionField<V extends string>({
  label,
  value,
  options,
  optionLabel,
  onChange,
  disabled,
  wrap = true,
  hint,
}: ReaderOptionFieldProps<V>) {
  return (
    <div className="grid gap-2">
      <Label>{label}</Label>
      <ToggleGroup
        type="single"
        value={value}
        onValueChange={(v) => {
          if (options.includes(v as V)) onChange(v as V);
        }}
        variant="outline"
        className={wrap ? "flex-wrap justify-start" : "justify-start"}
        disabled={disabled}
      >
        {options.map((option) => (
          <ToggleGroupItem
            key={option}
            value={option}
            aria-label={optionLabel(option)}
          >
            {optionLabel(option)}
          </ToggleGroupItem>
        ))}
      </ToggleGroup>
      {hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

interface ReaderSpreadFieldProps {
  id: string;
  label: string;
  value: boolean;
  onChange: (value: boolean) => void;
  onLabel: string;
  offLabel: string;
  disabled?: boolean;
}

export function ReaderSpreadField({
  id,
  label,
  value,
  onChange,
  onLabel,
  offLabel,
  disabled,
}: ReaderSpreadFieldProps) {
  return (
    <div className="flex items-center justify-between gap-3">
      <Label htmlFor={id}>{label}</Label>
      <Toggle
        id={id}
        pressed={value}
        onPressedChange={onChange}
        variant="outline"
        size="sm"
        aria-label={label}
        disabled={disabled}
      >
        {value ? onLabel : offLabel}
      </Toggle>
    </div>
  );
}

interface ReaderFontSizeFieldProps {
  label: string;
  value: number;
  onChange: (value: number) => void;
  disabled?: boolean;
}

export function ReaderFontSizeField({
  label,
  value,
  onChange,
  disabled,
}: ReaderFontSizeFieldProps) {
  return (
    <div className="grid gap-2">
      <Label>{label}</Label>
      <div className="flex items-center gap-2">
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => onChange(value - READER_FONT_SIZE_STEP)}
          disabled={disabled || value <= READER_FONT_SIZE_MIN}
        >
          -
        </Button>
        <span className="min-w-12 text-center text-sm tabular-nums">{value}%</span>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => onChange(value + READER_FONT_SIZE_STEP)}
          disabled={disabled || value >= READER_FONT_SIZE_MAX}
        >
          +
        </Button>
      </div>
    </div>
  );
}
