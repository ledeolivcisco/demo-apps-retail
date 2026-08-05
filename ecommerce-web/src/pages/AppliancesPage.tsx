import { useEffect, useState } from "react";
import type { Appliance, ApplianceType } from "@/types";
import { fetchAppliances } from "@/api/client";
import { ApplianceCard } from "@/components/ApplianceCard";

const TYPE_OPTIONS: { value: ApplianceType | ""; label: string }[] = [
  { value: "", label: "All types" },
  { value: "FRIDGE", label: "Fridges" },
  { value: "OVEN", label: "Ovens" },
  { value: "WASHING_MACHINE", label: "Washing machines" },
];

export function AppliancesPage() {
  const [appliances, setAppliances] = useState<Appliance[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [type, setType] = useState<ApplianceType | "">("");
  const [search, setSearch] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const list = await fetchAppliances(type || undefined, search.trim() || undefined);
        if (!cancelled) setAppliances(list);
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : "Failed to load appliances");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [type, search]);

  return (
    <div className="page">
      <div className="page-hero">
        <h1 className="page-title">Shop appliances</h1>
        <p className="page-subtitle">
          Fridges, ovens, and washing machines from our appliance catalog.
        </p>
      </div>

      <div className="filter-row">
        <select
          className="filter-select"
          value={type}
          onChange={(e) => setType(e.target.value as ApplianceType | "")}
          aria-label="Filter by appliance type"
        >
          {TYPE_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
        <input
          type="search"
          className="filter-search"
          placeholder="Search appliances…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          aria-label="Search appliances"
        />
      </div>

      {error ? (
        <div className="alert alert-error">
          <strong>Could not reach the appliance service.</strong>
          <p>{error}</p>
        </div>
      ) : loading ? (
        <p className="muted">Loading appliances…</p>
      ) : appliances.length === 0 ? (
        <p className="muted">No appliances match your search.</p>
      ) : (
        <div className="product-grid">
          {appliances.map((a) => (
            <ApplianceCard key={a.applianceId} appliance={a} />
          ))}
        </div>
      )}
    </div>
  );
}
