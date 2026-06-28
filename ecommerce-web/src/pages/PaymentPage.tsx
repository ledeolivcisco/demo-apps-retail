import { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import type { PayResponse } from "@/types";
import { submitCheckout } from "@/api/client";
import { useCart } from "@/context/CartContext";
import { endSession } from "@/session/shoppingSession";

type LocationState = {
  total?: number;
};

export function PaymentPage() {
  const location = useLocation();
  const { refreshCart } = useCart();
  const total = (location.state as LocationState | null)?.total;

  const invalidAmount =
    total == null || Number.isNaN(Number(total)) || Number(total) <= 0;

  const [result, setResult] = useState<PayResponse | null>(null);
  const [loading, setLoading] = useState(() => !invalidAmount);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (invalidAmount) {
      return;
    }

    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await submitCheckout(Number(total));
        if (!cancelled) {
          setResult(res);
          if (res.status === "success") {
            endSession();
          }
          try {
            await refreshCart();
          } catch {
            // Checkout succeeded; refresh is best-effort for UX sync
          }
        }
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : "Checkout failed");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [invalidAmount, refreshCart, total]);

  if (invalidAmount) {
    return (
      <div className="page payment-page">
        <div className="page-hero">
          <h1 className="page-title">Payment</h1>
          <p className="page-subtitle">
            Checkout runs in the cart service: inventory update, then payment confirmation.
          </p>
        </div>
        <div className="alert alert-error">
          <p>No payment amount. Open this page from the cart using Pay.</p>
          <Link to="/cart" className="btn btn-secondary">
            Back to cart
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page payment-page">
      <div className="page-hero">
        <h1 className="page-title">Payment</h1>
        <p className="page-subtitle">
          Checkout runs in the cart service: inventory update, then payment confirmation.
        </p>
      </div>

      {loading ? (
        <p className="muted">Processing checkout…</p>
      ) : error ? (
        <div className="alert alert-error">
          <p>{error}</p>
          <Link to="/cart" className="btn btn-secondary">
            Back to cart
          </Link>
        </div>
      ) : result ? (
        <div className="payment-result card-elevated">
          <div className={`status-pill status-${result.status}`}>{result.status}</div>
          <p className="payment-message">{result.message}</p>
          <p className="muted small">Amount sent: {formatMoney(Number(total))}</p>
          <div className="payment-actions">
            <Link to="/" className="btn btn-secondary">
              Continue shopping
            </Link>
            <Link to="/cart" className="btn btn-primary">
              View cart
            </Link>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function formatMoney(n: number): string {
  return new Intl.NumberFormat(undefined, {
    style: "currency",
    currency: "USD",
  }).format(n);
}
