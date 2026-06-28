import { useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useCart } from "@/context/CartContext";

export function CartPage() {
  const navigate = useNavigate();
  const { cart, loading, error, refreshCart } = useCart();

  useEffect(() => {
    void refreshCart();
  }, [refreshCart]);

  const lines = cart?.lineItems ?? [];
  const total = cart?.total ?? 0;
  const canPay = lines.length > 0 && total > 0;

  function handlePay() {
    navigate("/payment", { state: { total } });
  }

  return (
    <div className="page cart-page">
      <div className="page-hero">
        <h1 className="page-title">Your cart</h1>
        <p className="page-subtitle">
          Review items before checkout. Totals come from the cart service.
        </p>
      </div>

      {error ? (
        <div className="alert alert-error">
          <p>{error}</p>
        </div>
      ) : null}

      {loading && !cart ? (
        <p className="muted">Loading cart…</p>
      ) : lines.length === 0 ? (
        <div className="empty-cart">
          <p>Your cart is empty.</p>
          <Link to="/" className="btn btn-secondary">
            Browse products
          </Link>
        </div>
      ) : (
        <>
          <ul className="cart-list">
            {lines.map((line) => (
              <li key={line.productId} className="cart-row">
                <img
                  src={line.productPicture}
                  alt=""
                  width={64}
                  height={64}
                  className="cart-thumb"
                  loading="lazy"
                />
                <div className="cart-row-main">
                  <span className="cart-desc">{line.productDescription}</span>
                  <span className="muted small">
                    {formatMoney(line.productPrice)} × {line.quantity}
                  </span>
                </div>
                <div className="cart-row-total">
                  {formatMoney(line.productPrice * line.quantity)}
                </div>
              </li>
            ))}
          </ul>
          <div className="cart-footer">
            <div className="cart-total-row">
              <span>Total</span>
              <strong>{formatMoney(total)}</strong>
            </div>
            <button
              type="button"
              className="btn btn-primary btn-pay"
              disabled={!canPay}
              onClick={handlePay}
            >
              Pay
            </button>
          </div>
        </>
      )}
    </div>
  );
}

function formatMoney(n: number): string {
  return new Intl.NumberFormat(undefined, {
    style: "currency",
    currency: "USD",
  }).format(n);
}
