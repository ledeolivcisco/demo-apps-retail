import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { initObservability } from "@/observability/initObservability";
import { CartProvider } from "@/context/CartContext";
import { App } from "@/App";
import "@/index.css";

void initObservability().then(() => {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <BrowserRouter>
        <CartProvider>
          <App />
        </CartProvider>
      </BrowserRouter>
    </StrictMode>,
  );
});
