# Category taxonomy

Top-level categories are seeded in `CategoryService.defaultCategories` and stored per user in Firestore `users/{uid}/categories`. Optional **subcategories** refine a spend without adding more top-level pills.

## Groceries vs Food vs Shopping

| Category | Id | Use for |
|----------|-----|---------|
| Groceries | `groceries` | Supermarkets and grocery delivery (BigBasket, Zepto, Blinkit, DMart, Instamart) — household consumables |
| Food & Dining | `food` | Prepared meals and restaurant delivery (Swiggy, Zomato, dine-in, cafés) — not raw grocery runs |
| Shopping | `shopping` | General retail: fashion, electronics, marketplaces (Amazon, Flipkart, Myntra) — non-grocery goods |

Quick-commerce names (Zepto, Blinkit) map to **groceries** via merchant rules, not food.

## Rides & Commute vs Travel

| Category | Id | Use for |
|----------|-----|---------|
| Rides & Commute | `transport` | Daily local mobility: Uber/Ola/Rapido, metro, fuel, parking |
| Travel | `travel` | Trips: flights, hotels, IRCTC/RedBus, MakeMyTrip, Oyo |

Ride providers can also be captured in `travelProvider` on the transaction when classifying transport/travel.

## Shopping list vs subcategories

| Mechanism | Field | Categories | Purpose |
|-----------|-------|------------|---------|
| Shopping list | `shoppingItems` | `groceries`, `shopping` | Free-text item chips (Milk, Rice) in classify UI |
| Subcategories | `subcategoryId` | See table below | Structured refine (delivery vs dine-in, rent vs electricity) |
| Travel provider | `travelProvider` | `transport`, `travel` | App/service name (Uber, Ola) — presets + custom |

## Subcategories

Stored on `Transaction.subcategoryId` (and Firestore `subcategoryId`). Defined in `lib/models/category_taxonomy.dart`.

| Parent | Subcategory ids |
|--------|-----------------|
| `groceries` | `supermarket`, `quick_commerce` |
| `bills` | `internet`, `rent`, `electricity`, `water`, `phone`, `dth`, `gas`, `other` |
| `food` | `delivery`, `dine_in`, `takeaway`, `cafe` |
| `transport` | `ride_hail`, `transit`, `fuel`, `parking` |
| `travel` | `flight`, `hotel`, `train`, `package` |
