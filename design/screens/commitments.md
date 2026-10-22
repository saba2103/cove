# Commitments — `lib/features/subscriptions/subscriptions_screen.dart`

Reference: `commitments.png` · Budget: 28 · Overflow: `subscriptions_screen.cover` AND `subscriptions_screen.phone`

**This screen overflows at 411dp today — on an ordinary phone, not just the Fold.** Fixing that is part of this conversion, not a follow-up.

## Order
1. `CovePageHeader` — "Commitments", `CoveRoundButton` gold add. The bar calls this page **Bills**; the page itself does not.
2. Monthly total card with a split bar (EMIs / subs / savings).
3. "The runway" — caption with two icon buttons: EMIs page, full-year page.
4. Segment filter: All · Subs · EMIs · Savings.
5. Next-due block, then the list of commitments as `CoveRow`, each with its kind tag, payer avatar, financed-through source and amount.

## Rules
- A commitment renews itself; it is never "completed". An EMI counts down and ends.
- Show the **financed-through source** (`· via HDFC Regalia`) wherever the reference does.
- Due-soon items carry `status.alert` as a mark plus the words — never colour alone.
