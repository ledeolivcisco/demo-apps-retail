import type { Product } from "@/types";
import { useState } from "react";
import { addProductToCart } from "@/api/client";
import { useCart } from "@/context/CartContext";

type Props = {
  product: Product;
};

export function ProductCard({ product }: Props) {
  const { refreshCart } = useCart();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function handleAdd() {
    setBusy(true);
    setMsg(null);
    try {
      await addProductToCart(product.productId);
      await refreshCart();
      setMsg("Added");
      window.setTimeout(() => setMsg(null), 1500);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Error");
    } finally {
      setBusy(false);
    }
  }

  const price = formatMoney(product.productPrice);

  return (
    <article className="product-card">
      <div className="product-image-wrap">
        <img
          src={product.productPicture}
          alt=""
          className="product-image"
          loading="lazy"
          width={200}
          height={200}
        />
      </div>
      <div className="product-body">
        <h2 className="product-title">{product.productDescription}</h2>
        <p className="product-price">{price}</p>
        <button
          type="button"
          className="btn btn-primary"
          onClick={handleAdd}
          disabled={busy}
        >
          {busy ? "Adding…" : "Add to cart"}
        </button>
        {msg ? <p className="product-hint">{msg}</p> : null}
      </div>
    </article>
  );
}

function formatMoney(n: number): string {
  return new Intl.NumberFormat(undefined, {
    style: "currency",
    currency: "USD",
  }).format(n);
}
