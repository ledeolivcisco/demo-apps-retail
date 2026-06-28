# APDEX Simulation in AppDynamics Browser RUM — Summary

## Context

AppDynamics **does not have a native APDEX metric** for Browser RUM. This guide documents how to build one from scratch using Analytics (ADQL) and Dashboard Metric Expressions.

---

## APDEX Formula

```
APDEX = (Satisfied + Tolerated * 0.5) / Total
```

- **Satisfied** — `pageexperience = "Normal"`
- **Tolerated** — `pageexperience = "Slow"`
- **Frustrated** — `pageexperience IN ("Very Slow", "Stall", "Error")` → contributes 0
- Result is a value between **0.0** and **1.0** (not a percentage)

---

## Final Working Queries (3 Saved Analytics Metrics)

Replace `<EUM_APP_KEY>` with your Browser RUM app key from the AppDynamics Controller.

### Satisfied
```sql
SELECT count(*) FROM browser_records 
WHERE appkey = "<EUM_APP_KEY>" AND toString(pageexperience) = "Normal"
```

### Tolerated
```sql
SELECT count(*) FROM browser_records 
WHERE appkey = "<EUM_APP_KEY>" AND toString(pageexperience) = "Slow"
```

### Frustrated *(optional — for validation and alerting)*
```sql
SELECT count(*) FROM browser_records 
WHERE appkey = "<EUM_APP_KEY>" 
AND toString(pageexperience) IN ("Very Slow", "Stall", "Error")
```

### Total
```sql
SELECT count(*) FROM browser_records 
WHERE appkey = "<EUM_APP_KEY>"
```

---

## Dashboard Metric Expression

```
({APDEX_Satisfied} + ({APDEX_Tolerated} * 0.5)) / {APDEX_Total}
```

---

## APDEX Score Reference

| Result (x1000) | Real Score | Rating |
|---|---|---|
| 1000 | 1.0 | Excellent |
| 940 – 999 | 0.94 – 0.99 | Excellent |
| 850 – 939 | 0.85 – 0.93 | Good |
| 700 – 849 | 0.70 – 0.84 | Fair |
| 500 – 699 | 0.50 – 0.69 | Poor |
| 0 – 499 | 0.00 – 0.49 | Unacceptable |

---

## Diagnostic Query (for validation in Analytics UI)

Use this query to inspect raw counts per experience bucket before creating metrics:

```sql
SELECT pageexperience, count(*) 
FROM browser_records 
WHERE appkey = "<EUM_APP_KEY>"
```

Also useful to validate component counts sum to total:

```
Satisfied + Tolerated + Frustrated = Total
```

---

## Limitations

- No native decimal support in metrics — factor 1000 workaround required
- No `MIN()` or `IF()` in metric expressions — cannot cap result at 1000 natively
- Metric collection timing skew can cause values slightly above 1000
- All math must live in the Dashboard Metric Expression, not in the ADQL query
- `filter()` function only works reliably on numeric fields — use `WHERE` + `toString()` for string fields

---

## References

- [APDEX Specification](https://www.apdex.org)
