import { Link } from "react-router-dom";
import { useCart } from "@/context/CartContext";

export function Header() {
  const { itemCount } = useCart();

  return (
    <header className="app-header">
      <Link to="/" className="brand">
        <span className="brand-mark" aria-hidden />
        <span className="brand-text">FreshMart</span>
      </Link>
      <nav className="header-actions">
        <Link to="/cart" className="cart-link" aria-label="Open shopping cart">
          <CartIcon />
          {itemCount > 0 ? (
            <span className="cart-badge">{itemCount > 99 ? "99+" : itemCount}</span>
          ) : null}
        </Link>
      </nav>
    </header>
  );
}

function CartIcon() {
  return (
    <svg
      className="cart-icon"
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden
    >
      <path
        d="M6 6h15l-1.5 9h-12L4 3H1"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="9" cy="20" r="1.5" fill="currentColor" />
      <circle cx="18" cy="20" r="1.5" fill="currentColor" />
    </svg>
  );
}
