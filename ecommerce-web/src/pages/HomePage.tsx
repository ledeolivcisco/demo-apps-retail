import { useEffect, useState } from "react";
import type { Product } from "@/types";
import { fetchProducts } from "@/api/client";
import { ProductCard } from "@/components/ProductCard";
import { startSession } from "@/session/shoppingSession";

export function HomePage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      startSession();
      setLoading(true);
      setError(null);
      try {
        const list = await fetchProducts();
        if (!cancelled) setProducts(list);
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : "Failed to load catalog");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <div className="page">
        <p className="muted">Loading fresh groceries…</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="page">
        <div className="alert alert-error">
          <strong>Could not reach the product service.</strong>
          <p>{error}</p>
          <p className="muted small">
            Start the Spring Boot APIs (ports 8081–8083) and run{" "}
            <code>npm run dev</code> so Vite can proxy requests.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <div className="page-hero">
        <h1 className="page-title">Shop the aisles</h1>
        <p className="page-subtitle">
          Everyday staples delivered from our mock supermarket backends.
        </p>
      </div>
      <div className="product-grid">
        {products.map((p) => (
          <ProductCard key={p.productId} product={p} />
        ))}
      </div>
    </div>
  );
}
