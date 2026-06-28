import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { CartResponse } from "@/types";
import { fetchCart } from "@/api/client";

type CartContextValue = {
  cart: CartResponse | null;
  itemCount: number;
  loading: boolean;
  error: string | null;
  refreshCart: () => Promise<void>;
};

const CartContext = createContext<CartContextValue | undefined>(undefined);

export function CartProvider({ children }: { children: ReactNode }) {
  const [cart, setCart] = useState<CartResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refreshCart = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const next = await fetchCart();
      setCart(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not refresh cart");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refreshCart();
  }, [refreshCart]);

  const itemCount = useMemo(() => {
    if (!cart?.lineItems?.length) return 0;
    return cart.lineItems.reduce((sum, line) => sum + line.quantity, 0);
  }, [cart]);

  const value = useMemo(
    () => ({
      cart,
      itemCount,
      loading,
      error,
      refreshCart,
    }),
    [cart, itemCount, loading, error, refreshCart],
  );

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart(): CartContextValue {
  const ctx = useContext(CartContext);
  if (!ctx) {
    throw new Error("useCart must be used within CartProvider");
  }
  return ctx;
}
