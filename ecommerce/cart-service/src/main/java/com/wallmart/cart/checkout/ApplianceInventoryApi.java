package com.wallmart.cart.checkout;

import com.wallmart.cart.model.CartLineItem;
import java.util.List;

public interface ApplianceInventoryApi {

  void deduct(List<CartLineItem> lines);

  void restore(List<CartLineItem> lines);
}
