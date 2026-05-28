import { useTranslation } from "react-i18next";
import { X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useUsers } from "@/hooks/useUsers";

interface UserMultiSelectProps {
  value: number[];
  onChange: (ids: number[]) => void;
  // The owner is implicitly allowed and must not appear as a share option.
  excludeUserId?: number;
}

export function UserMultiSelect({ value, onChange, excludeUserId }: UserMultiSelectProps) {
  const { t } = useTranslation();
  const { data } = useUsers();
  const users = data?.users ?? [];
  const byId = new Map(users.map((u) => [u.id, u]));

  const selectable = users.filter((u) => u.id !== excludeUserId && !value.includes(u.id));

  const add = (id: string) => {
    const n = Number(id);
    if (!value.includes(n)) onChange([...value, n]);
  };
  const remove = (id: number) => onChange(value.filter((v) => v !== id));

  return (
    <div className="grid gap-2">
      {/* Remount on every change so the trigger resets to the placeholder
          and behaves as an "add" picker rather than a single-select. */}
      <Select key={value.join(",")} onValueChange={add} disabled={selectable.length === 0}>
        <SelectTrigger className="w-full">
          <SelectValue placeholder={t("settings.libraries.dialog.sharePlaceholder")} />
        </SelectTrigger>
        <SelectContent>
          {selectable.map((u) => (
            <SelectItem key={u.id} value={String(u.id)}>
              {u.email_address}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      {value.length > 0 ? (
        <div className="flex flex-wrap gap-1.5">
          {value.map((id) => (
            <Badge key={id} variant="secondary" className="gap-1">
              {byId.get(id)?.email_address ?? `#${id}`}
              <button
                type="button"
                onClick={() => remove(id)}
                aria-label={t("common.remove")}
                className="rounded-full hover:text-destructive"
              >
                <X className="size-3" aria-hidden />
              </button>
            </Badge>
          ))}
        </div>
      ) : null}
    </div>
  );
}
